#import "SentryFlutterReplayScreenshotProvider.h"
#import <Flutter/Flutter.h>

@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED

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
  NSLog(@"SentryFlutterReplayScreenshotProvider.image() called");
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:nil
            result:^(id value) {
              if (value == nil) {
                NSLog(@"SentryFlutterReplayScreenshotProvider received null "
                      @"result. "
                      @"Cannot capture a replay screenshot.");
              } else if ([value
                             isKindOfClass:[FlutterStandardTypedData class]]) {
                // TODO verify performance and reduce copying.
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
