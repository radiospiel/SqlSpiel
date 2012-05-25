//
//  SqlSpielTests.m
//  SqlSpielTests
//
//  Created by Enrico Thierbach on 25.05.12.
//  Copyright (c) 2012 n/a. All rights reserved.
//

#import "SqlSpielTests.h"

@implementation SqlSpielTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in SqlSpielTests");
}

@end


#if 0

/* --- Tests --------------------------------------- */

#import "M3.h"

ETest(GTMSQLiteStatementSqlSpielStatement)

-(SqlDatabase*) database
{
  SqlDatabase* db = [SqlDatabase databaseInMemory];
  [db executeSQL:@"CREATE TABLE t1 (x TEXT);"];
  
  // Insert data set
  [db executeSQL:@"INSERT INTO t1 VALUES ('foo');"];
  [db executeSQL:@"INSERT INTO t1 VALUES ('bar');"];
  [db executeSQL:@"INSERT INTO t1 VALUES ('yihaa');"];
  
  return db;
} 

-(void)test_sql_query_type
{
  assert_equal_int(StatementTypeDelete, statementTypeForSql(@"  Delete From"));
  assert_equal_int(StatementTypeSelect, statementTypeForSql(@"  sElECT From"));
  assert_equal_int(StatementTypeInsert, statementTypeForSql(@"INSert From"));
  assert_equal_int(StatementTypeUpdate, statementTypeForSql(@"Update From"));
}

-(void)test_ask_select
{
  SqlDatabase* db = [SqlDatabase databaseInMemory]; 
  NSNumber* one = [NSNumber numberWithInt: 1];
  assert_equal(([db ask: @"SELECT ?", one]), 1);
}

-(void)test_ask_insert
{
  SqlDatabase* db = [self database];
  assert_equal(([db ask: @"SELECT COUNT(*) FROM t1"]), 3);
  assert_equal(([db ask: @"INSERT INTO t1 VALUES(?)", @"test"]), 4);
  assert_equal(([db ask: @"SELECT COUNT(*) FROM t1"]), 4);
}

-(void)test_ask_delete
{
  SqlDatabase* db = [self database];
  assert_equal(([db ask: @"DELETE FROM t1 WHERE x=?", @"foo"]), 1);
  assert_equal(([db ask: @"DELETE FROM t1"]), 2);
  assert_equal(([db ask: @"DELETE FROM t1"]), 0);
}

-(void)test_ask_update
{
  SqlDatabase* db = [self database];
  assert_equal(([db ask: @"UPDATE t1 SET x=? WHERE x=?", @"bar", @"foo"]), 1);
  assert_equal(([db ask: @"UPDATE t1 SET x=?", @"bar"]), 3);
}

// --------------------------------------

-(void)test_select_fast_enumeration
{
  SqlDatabase* db = [self database];

  NSMutableArray* rows = [NSMutableArray array];
  for(NSArray* row in [db eachArray: @"SELECT * FROM t1"]) {
    [rows addObject: row];
  }

  assert_equal(rows, _.array( _.array("foo"),
                              _.array("bar"),
                              _.array("yihaa")
  ));

  rows = [NSMutableArray array];
  for(NSDictionary* row in [db each: @"SELECT * FROM t1"]) {
    [rows addObject: row];
  }

  assert_equal(rows, _.array( _.hash("x", "foo"),
                              _.hash("x", "bar"),
                              _.hash("x", "yihaa")
  ));
}

-(void)test_select_empty_fast_enumeration
{
  SqlDatabase* db = [self database];

  NSMutableArray* rows = [NSMutableArray array];
  for(NSArray* row in [db eachArray: @"SELECT * FROM t1 WHERE x=1"]) {
    [rows addObject: row];
  }

  assert_equal(rows, _.array());

  rows = [NSMutableArray array];
  for(NSArray* row in [db each: @"SELECT * FROM t1 WHERE x=1"]) {
    [rows addObject: row];
  }
  assert_equal(rows, _.array());
}

-(void)test_select_fast_enumeration_with_binding
{
  SqlDatabase* db = [self database];

  NSMutableArray* rows = [NSMutableArray array];
  for(NSArray* row in [db eachArray: @"SELECT * FROM t1 WHERE x < ? AND x > ?", @"mm", @"cc"]) {
    [rows addObject: row];
  }
  assert_equal(rows, _.array( _.array("foo")));

  rows = [NSMutableArray array];
  for(NSArray* row in [db eachArray: @"SELECT * FROM t1 WHERE x > ? AND x < ?", @"cc", @"mm"]) {
    [rows addObject: row];
  }
  assert_equal(rows, _.array( _.array("foo")));
}

#define REMOTE_SQL_URL  @"http://localhost:3000/db/images,berlin.sql"

-(void)test_import_sql
{
  SqlDatabase* db = [SqlDatabase databaseInMemory];
  
  NSArray* entries = [M3 readJSON: REMOTE_SQL_URL];
  if(![entries isKindOfClass: [NSArray class]])
    _.raise("Cannot read file ", REMOTE_SQL_URL);
  

  [db importDump: entries];
}

@end

#endif
