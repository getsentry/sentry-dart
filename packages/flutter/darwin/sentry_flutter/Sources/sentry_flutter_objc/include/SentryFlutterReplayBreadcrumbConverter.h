@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED
@class SentryRRWebEvent;

/// Breadcrumb data key holding the network request/response details captured
/// on the Dart side. The `__sentry` prefix keeps it out of serialized events,
/// so the details only reach Session Replay.
FOUNDATION_EXPORT NSString *_Nonnull const
    SentryFlutterReplayNetworkDetailsKey;

@interface SentryFlutterReplayBreadcrumbConverter
    : NSObject <SentryReplayBreadcrumbConverter>

- (instancetype _Nonnull)init;

- (id<SentryRRWebEvent> _Nullable)convertFrom:
    (SentryBreadcrumb *_Nonnull)breadcrumb;

@end
#endif
