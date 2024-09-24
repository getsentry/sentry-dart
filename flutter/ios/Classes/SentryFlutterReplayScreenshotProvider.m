@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED
#import "SentryFlutterReplayScreenshotProvider.h"
#import <Flutter/Flutter.h>

@implementation SentryFlutterReplayScreenshotProvider {
  FlutterMethodChannel *channel;
}

- (instancetype _Nonnull)initWithChannel:
    (FlutterMethodChannel *_Nonnull)channel {
  if (self = [super init]) {
    self->channel = channel;
  }
  return self;
}

- (void)imageWithView:(UIView *_Nonnull)view
              options:(id<SentryRedactOptions> _Nonnull)options
           onComplete:(void (^_Nonnull)(UIImage *_Nonnull))onComplete {
  NSString *replayId = [PrivateSentrySDKOnly getReplayId];
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:@{@"replayId" : replayId ? replayId : [NSNull null]}
            result:^(id value) {
              if (value == nil) {
                NSLog(@"SentryFlutterReplayScreenshotProvider received null "
                      @"result. "
                      @"Cannot capture a replay screenshot.");
              } else if ([value
                             isKindOfClass:[FlutterStandardTypedData class]]) {
                FlutterStandardTypedData *typedData =
                    (FlutterStandardTypedData *)value;
                UIImage *image = [UIImage imageWithData:typedData.data];
                onComplete(image);
              } else if ([value isKindOfClass:[FlutterError class]]) {
                FlutterError *error = (FlutterError *)value;
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"error: %@. Cannot capture a replay screenshot.",
                      error.message);
              } else {
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"unexpected result. "
                      @"Cannot capture a replay screenshot.");
              }
            }];
}

@end

#endif
