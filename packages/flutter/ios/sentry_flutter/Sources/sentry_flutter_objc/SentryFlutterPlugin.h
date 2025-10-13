#import <Foundation/Foundation.h>

#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
#import <sentry_flutter/sentry_flutter-Swift.h>
#else
@interface SentryFlutterPlugin : NSObject
+ (nullable NSNumber *)getDisplayRefreshRate;
+ (nullable NSData *)fetchNativeAppStartAsBytes;
+ (nullable NSData *)loadContextsAsBytes;
+ (nullable NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
+ (void)setUserAsBytes:(nullable NSData *)userBytes;
+ (void)addBreadcrumbAsBytes:(NSData *)breadcrumbBytes;
+ (void)clearBreadcrumbs;
+ (void)nativeCrash;
+ (void)pauseAppHangTracking;
+ (void)resumeAppHangTracking;
@end
#endif
