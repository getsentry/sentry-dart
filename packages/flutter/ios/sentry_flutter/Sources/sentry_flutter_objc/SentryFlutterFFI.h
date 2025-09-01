#import <Foundation/Foundation.h>

@interface SentryFlutterFFI : NSObject
+ (nullable NSData *)loadContextsAsBytes;
+ (nullable NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
@end


