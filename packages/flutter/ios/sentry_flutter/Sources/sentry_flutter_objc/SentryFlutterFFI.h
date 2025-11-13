// These are needed for objc_generated_bindings.m
@protocol SentrySpan;
@protocol SentrySerializable;
@protocol SentryRedactOptions;

// Only included while running ffigen (provide -I paths in compiler-opts).
#ifdef FFIGEN
#import "SentryFlutterReplayScreenshotProvider.h"
#import "PrivateSentrySDKOnly.h"
#import "Sentry-Swift.h"
#import "SentryOptions.h"
#import "SentryScope.h"

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
        port:(NSNumber *)port
        type:(NSString *)type;
+ (void)setReplayOptions:(SentryOptions *)options
        quality:(NSInteger)quality
        sessionSampleRate:(float)sessionSampleRate
        onErrorSampleRate:(float)onErrorSampleRate
        sdkName:(NSString *)sdkName
        sdkVersion:(NSString *)sdkVersion;
+ (void)setAutoPerformanceFeatures;
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
@end
#endif
