@import Sentry;

typedef void (^SentryReplayCaptureCallback)(
    NSString *_Nullable replayId,
    BOOL replayIsBuffering,
    void (^_Nonnull result)(id _Nullable value));

#if SENTRY_TARGET_REPLAY_SUPPORTED
@class SentryRRWebEvent;

@interface SentryFlutterReplayScreenshotProvider
    : NSObject <SentryViewScreenshotProvider>

- (instancetype)initWithChannel:(id)FlutterMethodChannel;

@end

@interface SentryFlutterReplayRecorderFFI
    : NSObject <SentryViewScreenshotProvider>

- (instancetype)initWithCallback:(SentryReplayCaptureCallback)callback;

@end
#endif
