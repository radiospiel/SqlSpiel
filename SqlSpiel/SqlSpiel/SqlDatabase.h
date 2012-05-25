//
//  SqlDatabase.h
//  SqlSpiel
//
//  Created by Enrico Thierbach on 25.05.12.
//  Copyright (c) 2012 n/a. All rights reserved.
//

#import "GTMSQLite.h"

@interface SqlDatabase: GTMSQLiteDatabase

@property (strong) NSMutableDictionary* cached_statements;
@property (strong) NSMutableArray* uncacheable_statements;

// returns an autorelese SqlDatabase
+ (SqlDatabase*)databaseWithPath:(NSString *)path
                 withCFAdditions:(BOOL)additions
                            utf8:(BOOL)useUTF8
                       errorCode:(int *)err;

// returns an autorelese SqlDatabase on a given path
+ (SqlDatabase*)databaseWithPath:(NSString *)path;

// returns an autorelese SqlDatabase in memory.
+ (SqlDatabase*)databaseInMemory;

// Execute a query and returns a single value result.
//
// This method returns
// - the number of affected rows for UPDATEs and DELETEs
// - the lastInsertedId for INSERTs
// - the first value in the first row of the result set or nil for SELECTs 
//
// [db ask: @"SELECT COUNT(*) FROM foo"];
// [db ask: @"SELECT COUNT(*) FROM foo WHERE id > ? AND id < ?", @"a", @"b"];
//
-(id)ask: (NSString*)sql, ...;
-(id)ask: (NSString*)sql withParameters: (NSArray*)params;

// Execute a select and enumerate over the result set.
//
// for(NSDictionary* record in [db select: @"SELECT * FROM foo WHERE id > ? AND id < ?", @"a", @"b"]) {
//   ..
// }
//
-(id)each: (NSString*)sql, ...;

// Execute a select and enumerate over the result set as arrays.
//
// for(NSArray* record in [db select: @"SELECT * FROM foo WHERE id > ? AND id < ?", @"a", @"b"]) {
//   ..
// }
//
-(id)eachArray: (NSString*)sql, ...;

// Execute a query and return the first result set as NSDictionary
-(NSDictionary*)first: (NSString*)sql, ...;

// Execute a query and return the complete result set as an array of dictionaries.
-(NSArray*)all: (NSString*)sql, ...;

// Execute a query and return the complete result set as an array of arrays.
-(NSArray*)allArrays: (NSString*)sql, ...;

-(void)transaction: (void(^)())block;

@end
