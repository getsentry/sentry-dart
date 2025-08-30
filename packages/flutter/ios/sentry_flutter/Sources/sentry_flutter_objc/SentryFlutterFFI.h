#import <Foundation/Foundation.h>

@interface SentryFlutterFFI : NSObject
+ (NSString *)loadContextsJSON;
+ (NSDictionary *)loadContexts;
// UTF-8 encoded JSON data
+ (NSData *)loadContextsNSData;
@end


