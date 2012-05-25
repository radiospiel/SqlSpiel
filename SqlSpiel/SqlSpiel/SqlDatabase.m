//
//  SqlSpiel.m
//  SqlSpiel
//
//  Created by Enrico Thierbach on 25.05.12.
//  Copyright (c) 2012 n/a. All rights reserved.
//

#import "SqlSpiel.h"

/*
 * The type of a SQL statement
 */
typedef enum {
  StatementTypeSelect = 0,
  StatementTypeInsert,
  StatementTypeUpdate,
  StatementTypeDelete,
  StatementTypeOther,
  
  StatementTypeSelectRow
} StatementType;

static StatementType statementTypeForSql(NSString* sql)
{
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: @"^\\s*(INSERT|DELETE|UPDATE|SELECT)"
                                                                         options: NSRegularExpressionCaseInsensitive
                                                                           error: NULL];
  
  NSArray* matches = [regex matchesInString:sql options: 0 range: NSMakeRange(0, [sql length])];
  if(!matches || [matches count] == 0) return StatementTypeOther;
  
  NSTextCheckingResult* match = [matches objectAtIndex:0];
  
  if(match) {
    NSRange matchRange = [match rangeAtIndex:1];
    NSString* matchedText = [sql substringWithRange:matchRange];
    
    matchedText = [matchedText uppercaseString];
    if([matchedText isEqualToString:@"INSERT"]) return StatementTypeInsert;
    if([matchedText isEqualToString:@"DELETE"]) return StatementTypeDelete;
    if([matchedText isEqualToString:@"UPDATE"]) return StatementTypeUpdate;
    if([matchedText isEqualToString:@"SELECT"]) return StatementTypeSelect;
  }
  
  return StatementTypeOther;
}

@implementation SqlDatabase

-(void)dealloc
{
  // finalize all prepared SQL statements.
  [cached_statements_ enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [obj finalizeStatement];
  }];
  
   cached_statements_ = nil;
  
  [uncacheable_statements_ enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    [obj finalizeStatement];
  }];
   uncacheable_statements_ = nil;
  
}

-(void) init_prepared_statements
{
  if(!cached_statements_)
    cached_statements_ = [[NSMutableDictionary alloc]init];
  
  if(!uncacheable_statements_)
    uncacheable_statements_ = [[NSMutableArray alloc]init];
}

-(GTMSQLiteStatement*)uncachedPrepareStatement: (NSString*)sql
{
  return [GTMSQLiteStatement statementWithSQL:sql inDatabase:self errorCode:NULL];
}

-(BOOL)isCacheableStatement: (NSString*)sql
{
  switch(statementTypeForSql(sql)) {
    case StatementTypeSelect:
    case StatementTypeInsert:
    case StatementTypeUpdate:
    case StatementTypeDelete: return YES;
      
    default: return NO;
  }
}

-(GTMSQLiteStatement*)prepareStatement: (NSString*)sql
{
  [self init_prepared_statements];
  
  GTMSQLiteStatement* statement;
  
  statement = [cached_statements_ objectForKey:sql];
  if(statement) return statement;
  
  statement = [self uncachedPrepareStatement: sql];
  if(!statement) return statement;
  
  if([self isCacheableStatement: sql]) {
    // NSLog(@"*** caching %@", sql);
    [cached_statements_ setObject: statement forKey:sql];
  }
  else {
    // NSLog(@"*** not caching %@", sql);
    [uncacheable_statements_ addObject: statement];
  }
  
  return statement;
}

// Execute a query and returns a single value result.
//
// The result is
//   the number of affected rows for UPDATEs and DELETEs
//   the lastInsertedId for INSERTs
//   the first value in the first row of the result set or nil for SELECTs 
//
// [db ask: @"SELECT COUNT(*) FROM foo"];
// [db ask: @"SELECT COUNT(*) FROM foo WHERE id > ? AND id < ?", @"a", @"b"];
//
-(id)askStatement: (GTMSQLiteStatement*)statement 
           ofType: (StatementType) statementType
{
  //
  // get the "sensible" return value
  id retVal = nil;
  
  int stepRowResult = [statement stepRow];
  
  switch(statementType) {
    case StatementTypeDelete:
    case StatementTypeUpdate:
      retVal = [NSNumber numberWithInt:[self lastChangeCount]];
      break;
    case StatementTypeInsert:
      retVal = [NSNumber numberWithUnsignedLongLong:[self lastInsertRowID]];
      break;
    case StatementTypeSelect:
      if(stepRowResult != SQLITE_DONE) {
        NSArray* row = [statement resultRowArray];
        retVal = [row objectAtIndex:0];
      }
      break;
    case StatementTypeSelectRow:
      if(stepRowResult != SQLITE_DONE) {
        retVal = [statement resultRowDictionary];
      }
      break;
    case StatementTypeOther:
      retVal = [NSNumber numberWithBool:YES];
      break;
  };
  
  [statement reset];
  return retVal;
}

-(id)askRow: (NSString*)sql, ...;
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  [statement reset];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  va_end(args);
  
  return [self askStatement: statement ofType: StatementTypeSelectRow ];
}

-(id)ask: (NSString*)sql, ...;
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  [statement reset];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  va_end(args);
  
  return [self askStatement: statement ofType: statementTypeForSql(sql) ];
}

-(id)ask: (NSString*)sql withParameters: (NSArray*)params
{
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  [statement reset];
  
  [params enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    [statement bindObject: obj atPosition: idx+1];
  }];
  
  return [self askStatement: statement ofType: statementTypeForSql(sql) ];
}

// Execute a select and enumerate over the result set.
//
// for(NSDictionary* record in [db select: @"SELECT * FROM foo WHERE id > ? AND id < ?", @"a", @"b"]) {
//   ..
// }
//
-(GTMSQLiteStatement*) each: (NSString*)sql, ...
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  
  va_end(args);
  
  statement.enumerationPolicy = SqlSpielEnumerateUsingDictionaries;
  return statement;
}

// Execute a select and enumerate over the result set as arrays.
//
// for(NSDictionary* record in [db select: @"SELECT * FROM foo WHERE id > ? AND id < ?", @"a", @"b"]) {
//   ..
// }
//
-(GTMSQLiteStatement*) eachArray: (NSString*)sql, ...
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  
  va_end(args);
  
  statement.enumerationPolicy = SqlSpielEnumerateUsingArrays;
  return statement;
}

// Execute a query and return the first result set as NSDictionary
-(NSDictionary*)first: (NSString*)sql, ...;
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  
  va_end(args);
  
  statement.enumerationPolicy = SqlSpielEnumerateUsingDictionaries;
  
  NSDictionary* result = nil;
  for(NSDictionary* record in statement) {
    result = record;
    break;
  }
  
  [statement reset];
  return result;
}

// Execute a query and return the complete result set as an array of dictionaries.
-(NSArray*)all: (NSString*)sql, ...;
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  
  va_end(args);
  
  statement.enumerationPolicy = SqlSpielEnumerateUsingDictionaries;
  
  NSMutableArray* array = [NSMutableArray array];
  for(NSDictionary* record in statement) {
    [array addObject:record];
  }
  return array;
}

// Execute a query and return the complete result set as an array of arrays.
-(NSArray*)allArrays: (NSString*)sql, ...;
{
  va_list args;
  va_start(args, sql);
  
  GTMSQLiteStatement* statement = [self prepareStatement:sql];
  
  int count = [statement parameterCount]; 
  
  for( int i = 0; i < count; i++ ) {
    id arg = va_arg(args, id);
    [statement bindObject: arg atPosition: i+1];
  }
  
  va_end(args);
  
  statement.enumerationPolicy = SqlSpielEnumerateUsingArrays;
  
  NSMutableArray* array = [NSMutableArray array];
  for(NSArray* record in statement) {
    [array addObject:record];
  }
  return array;
}

-(void)transaction: (void(^)())block
{
  @try {
    [self ask: @"BEGIN"];
    block();
    [self ask: @"COMMIT"];
  }
  @catch (NSException *exception) {
    [self ask: @"ROLLBACK"];
  }
  @finally {
    ;
  }
}

+ (SqlDatabase*)databaseWithPath:(NSString *)path
                 withCFAdditions:(BOOL)additions
                            utf8:(BOOL)useUTF8
                       errorCode:(int *)err
{
  return [[SqlDatabase alloc]initWithPath: path 
                           withCFAdditions: additions 
                                      utf8: useUTF8 
                                 errorCode: err];
}

+ (SqlDatabase*)databaseWithPath:(NSString *)path
{
  return [SqlDatabase databaseWithPath:path 
                       withCFAdditions:YES 
                                  utf8:YES 
                             errorCode:NULL];
}

+ (SqlDatabase*)databaseInMemory
{
  return [SqlDatabase databaseWithPath:@":memory:"];
}

@end
