@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED
@class SentryRRWebEvent;
@class FlutterMethodChannel;

@interface SentryFlutterReplayScreenshotProvider
    : NSObject <SentryViewScreenshotProvider>

- (instancetype _Nonnull)initWithChannel:(FlutterMethodChannel *_Nonnull)channel
                        replayIdProvider:
                            (NSString *_Nullable (^_Nonnull)(void))
                                replayIdProvider;

@end
#endif
