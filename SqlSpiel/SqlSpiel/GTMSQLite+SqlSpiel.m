#import "GTMSQLite+SqlSpiel.h"

#include <objc/runtime.h> // objc_setAssociatedObject & co.

@implementation GTMSQLiteStatement(SqlSpiel)

static NSString* kUseArrayEnumeration = @"kUseArrayEnumeration";

-(void)setEnumerationPolicy: (SqlSpielEnumerationPolicy)enumerationPolicy
{
  objc_setAssociatedObject(self, @"enumerationPolicy", 
                          (enumerationPolicy == SqlSpielEnumerateUsingArrays ? kUseArrayEnumeration : nil), 
                           OBJC_ASSOCIATION_ASSIGN);
}

-(SqlSpielEnumerationPolicy)enumerationPolicy;
{
  id currentPolicy = objc_getAssociatedObject(self, @"enumerationPolicy");
  return currentPolicy == kUseArrayEnumeration ? SqlSpielEnumerateUsingArrays : SqlSpielEnumerateUsingDictionaries;
}

-(id)resultRow
{
  id currentPolicy = objc_getAssociatedObject(self, @"enumerationPolicy");
  if(currentPolicy == kUseArrayEnumeration)
    return [self resultRowArray];

  return [self resultRowDictionary];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state 
                                  objects:(id __unsafe_unretained *)stackbuf 
                                    count:(NSUInteger)len;
{
  switch([self stepRow]) {
  case SQLITE_DONE:
    [self reset];
    return 0;
  case SQLITE_ROW:
    // stackbuf is an array for a few id entries on the stack, and
    // can be used to store ids, if needed. 
    *stackbuf = [self resultRow];

    state->state = 1;                             /* Apparently state must not be 0 ?? */
    state->itemsPtr = stackbuf;                   
    state->mutationsPtr = (unsigned long*)(__bridge void*)self;  
    return 1;
  default:
    return 0;
  }
}

-(int)bindObject: (id)obj atPosition: (NSUInteger)position
{
  if([obj isKindOfClass:[NSNull class]])
    return [self bindSQLNullAtPosition: (int)position];
  
  if([obj isKindOfClass:[NSString class]])
    return [self bindStringAtPosition: (int)position string:(NSString *)obj ];
  
  if([obj isKindOfClass:[NSData class]])
    return [self bindBlobAtPosition: (int)position data: (NSData *)obj];

  if([obj isKindOfClass:[NSNumber class]])
  {
    NSNumber* number = obj;

    const char* objCType = [number objCType];
    
    if (!strcmp(objCType, @encode(double)) || !strcmp(objCType, @encode(float)))
      return [self bindDoubleAtPosition: (int)position value: [number doubleValue]];
    
    // Instead of discriminate different integer lengths, we just bind all kind
    // of integers as long longs. The overhead of doing so is probably quite
    // negliable anyways, and there would be overhead of testing against 
    // all other @encodings.
    
    return [self bindNumberAsLongLongAtPosition: (int)position number: number];
  }

  if([obj isKindOfClass:[NSDate class]])
  {
    NSDate* date = (NSDate*)obj;
    
    NSNumber* number = [NSNumber numberWithInt: [date timeIntervalSince1970]];
    return [self bindNumberAsLongLongAtPosition: (int)position number: number];
  }

  NSLog(@"**** Trying to bind an unsupported object of type %@", [obj class]);
  return -1;
}

@end
