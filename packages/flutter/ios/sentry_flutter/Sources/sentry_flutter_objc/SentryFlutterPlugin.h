#import <Foundation/Foundation.h>

#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
#import <sentry_flutter/sentry_flutter-Swift.h>
#else
typedef void (^SentryReplayCaptureCallback)(
        NSString *_Nullable replayId,
        BOOL replayIsBuffering,
        void (^_Nonnull result)(id _Nullable value));

@class SentryOptions;
@class SentryEvent;
@class SentryReplayOptions;

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
+ (void)setAutoPerformanceFeatures:(BOOL)enableAutoPerformanceTracing;
+ (void)setEventOriginTag:(SentryEvent *)event;
+ (void)setSdkMetaData:(SentryEvent *)event
              packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
        integrations:(NSArray<NSString *> *)integrations;
+ (void)setBeforeSend:(SentryOptions *)options
        packages:(NSArray<NSDictionary<NSString *, NSString *> *> *)packages
        integrations:(NSArray<NSString *> *)integrations;
+ (void)setupHybridSdkNotifications;
+ (void)setupReplay:(SentryReplayCaptureCallback)callback
        tags:(NSDictionary<NSString *, NSString *> *)tags;
+ (nullable SentryReplayOptions *)getReplayOptions;
#endif
@end
