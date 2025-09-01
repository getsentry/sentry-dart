#import <Foundation/Foundation.h>

@interface SentryFlutterFFIBridge : NSObject
+ (nullable NSData *)loadContextsAsBytes;
+ (nullable NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
@end
