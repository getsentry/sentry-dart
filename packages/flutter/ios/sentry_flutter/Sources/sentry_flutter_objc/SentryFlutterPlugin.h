#import <Foundation/Foundation.h>

#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
#import <sentry_flutter/sentry_flutter-Swift.h>
#else
@interface SentryFlutterPlugin : NSObject
+ (nullable NSData *)loadContextsAsBytes;
+ (nullable NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
@end
#endif
