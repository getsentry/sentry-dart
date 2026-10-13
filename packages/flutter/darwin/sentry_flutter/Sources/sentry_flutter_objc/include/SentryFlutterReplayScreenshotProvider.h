@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED
@class SentryRRWebEvent;

@interface SentryFlutterReplayScreenshotProvider
    : NSObject <SentryViewScreenshotProvider>

- (instancetype)initWithChannel:(id)FlutterMethodChannel
                replayIdProvider:
                    (NSString *_Nullable (^_Nonnull)(void))replayIdProvider;

@end
#endif
