#import <Foundation/Foundation.h>

@import Sentry;

typedef void (^SentryReplayCaptureCallback)(
    NSString *_Nullable replayId,
    BOOL replayIsBuffering,
    void (^_Nonnull result)(id _Nullable value));

#if SENTRY_TARGET_REPLAY_SUPPORTED
@class SentryRRWebEvent;

@interface SentryFlutterReplayScreenshotProvider
    : NSObject <SentryViewScreenshotProvider>

- (instancetype)initWithCallback:(SentryReplayCaptureCallback _Nonnull)callback;

@end
#endif
