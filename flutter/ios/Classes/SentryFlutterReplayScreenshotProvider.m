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
           onComplete:(void (^_Nonnull)(UIImage *_Nonnull))onComplete {
  // Replay ID may be null if session replay is disabled.
  // Replay is still captured for on-error replays.
  NSString *replayId = [PrivateSentrySDKOnly getReplayId];
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:@{@"replayId" : replayId ? replayId : [NSNull null]}
            result:^(id value) {
              if (value == nil) {
                NSLog(@"SentryFlutterReplayScreenshotProvider received null "
                      @"result. "
                      @"Cannot capture a replay screenshot.");
              } else if ([value isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)value;
                long address = ((NSNumber *)dict[@"address"]).longValue;
                NSNumber *length = ((NSNumber *)dict[@"length"]);
                NSData *data =
                    [NSData dataWithBytesNoCopy:(void *)address
                                         length:length.unsignedLongValue
                                   freeWhenDone:TRUE];
                UIImage *image = [UIImage imageWithData:data];
                onComplete(image);
                return;
              } else if ([value isKindOfClass:[FlutterError class]]) {
                FlutterError *error = (FlutterError *)value;
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"error: %@. Cannot capture a replay screenshot.",
                      error.message);
                return;
              } else {
                NSLog(@"SentryFlutterReplayScreenshotProvider received an "
                      @"unexpected result. "
                      @"Cannot capture a replay screenshot.");
              }
            }];
}

@end

#endif
