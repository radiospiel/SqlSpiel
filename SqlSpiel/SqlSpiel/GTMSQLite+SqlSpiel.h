#import "GTMSQLite.h"

typedef enum SqlSpielEnumerationPolicy {
  SqlSpielEnumerateUsingDictionaries = 0,
  SqlSpielEnumerateUsingArrays = 1
} SqlSpielEnumerationPolicy;

@interface GTMSQLiteStatement(SqlSpielStatement)

@property (nonatomic,assign) SqlSpielEnumerationPolicy enumerationPolicy;

//
// Implements the NSFastEnumeration protocol.
-(NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state 
                                 objects:(id *)stackbuf 
                                   count:(NSUInteger)len;


-(int)bindObject: (id)obj atPosition: (NSUInteger)position;

@end
