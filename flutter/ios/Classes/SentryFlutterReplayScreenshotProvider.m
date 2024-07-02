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
    dispatch_async(dispatch_get_main_queue(), ^{
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:nil
            result:^(FlutterResult _Nullable flutterResult) {
              if (flutterResult == nil) {
                NSLog(@"SentryFlutterReplayScreenshotProvider received null "
                      @"result. Cannot capture a replay screenshot.");
              } else if ([flutterResult isKindOfClass:[FlutterStandardTypedData class]]) {
                FlutterStandardTypedData* typedData = (FlutterStandardTypedData*)flutterResult;
                UIImage *image = [UIImage imageWithData:typedData.data];
                onComplete(image);
              } else {
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"unexpected result. Cannot capture a replay screenshot.");
              }
            }];
    });
}

@end

#endif
