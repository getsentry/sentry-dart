#import <Foundation/Foundation.h>

#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
#import <sentry_flutter/sentry_flutter-Swift.h>
#else
@class SentryOptions;

@interface SentryFlutterPlugin : NSObject
+ (nullable NSNumber *)getDisplayRefreshRate;
+ (nullable NSData *)fetchNativeAppStartAsBytes;
+ (nullable NSData *)loadContextsAsBytes;
+ (nullable NSData *)loadDebugImagesAsBytes:(NSSet<NSString *> *)instructionAddresses;
+ (nullable NSString *)captureReplay;
+ (void)setProxyOptions:(SentryOptions *)options
                        user:(NSString * _Nullable)user
                        pass:(NSString * _Nullable)pass
                        host:(NSString *)host
                        port:(NSString *)port
                        type:(NSString *)type;
+ (void)setReplayOptions:(SentryOptions *)options
                    quality:(NSInteger)quality
                    sessionSampleRate:(float)sessionSampleRate
                    onErrorSampleRate:(float)onErrorSampleRate
                   sdkName:(NSString *)sdkName
                   sdkVersion:(NSString *)sdkVersion;
@end
#endif
