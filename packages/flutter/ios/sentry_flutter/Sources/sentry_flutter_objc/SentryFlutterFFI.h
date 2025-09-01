#import <Foundation/Foundation.h>

@interface SentryFlutterFFI : NSObject
+ (NSData *)loadContextsAsBytes;
+ (NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
@end


