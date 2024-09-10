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
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:@{@"replayId" : [PrivateSentrySDKOnly getReplayId]}
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
              } else {
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"unexpected result. "
                      @"Cannot capture a replay screenshot.");
              }
            }];
}

@end

#endif
