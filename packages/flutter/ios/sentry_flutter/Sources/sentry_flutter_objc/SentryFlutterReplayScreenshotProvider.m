@import Sentry;

#if SWIFT_PACKAGE
@import Sentry._Hybrid;
#endif

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
  // On iOS, we only have access to scope's replay ID, so we cannot detect buffer mode
  // If replay ID exists, it's always in active session mode (not buffering)
  BOOL replayIsBuffering = NO;
  [self->channel
      invokeMethod:@"captureReplayScreenshot"
         arguments:@{
           @"replayId" : replayId ? replayId : [NSNull null],
           @"replayIsBuffering" : @(replayIsBuffering)
         }
            result:^(id value) {
              if (value == nil) {
                NSLog(@"SentryFlutterReplayScreenshotProvider received null "
                      @"result. "
                      @"Cannot capture a replay screenshot.");
              } else if ([value isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)value;
                long address = ((NSNumber *)dict[@"address"]).longValue;
                NSNumber *length = ((NSNumber *)dict[@"length"]);
                NSNumber *width = ((NSNumber *)dict[@"width"]);
                NSNumber *height = ((NSNumber *)dict[@"height"]);
                NSData *data =
                    [NSData dataWithBytesNoCopy:(void *)address
                                         length:length.unsignedLongValue
                                   freeWhenDone:TRUE];

                // We expect rawRGBA, see docs for ImageByteFormat:
                // https://api.flutter.dev/flutter/dart-ui/ImageByteFormat.html
                // Unencoded bytes, in RGBA row-primary form with premultiplied
                // alpha, 8 bits per channel.
                static const int kBitsPerChannel = 8;
                static const int kBytesPerPixel = 4;
                assert(length.unsignedLongValue % kBytesPerPixel == 0);

                // Let's create an UIImage from the raw data.
                // We need to provide it the width & height and
                // the info how the data is encoded.
                CGDataProviderRef provider =
                    CGDataProviderCreateWithCFData((CFDataRef)data);
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                CGBitmapInfo bitmapInfo =
                    kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
                CGImageRef cgImage = CGImageCreate(
                    width.unsignedLongValue,          // width
                    height.unsignedLongValue,         // height
                    kBitsPerChannel,                  // bits per component
                    kBitsPerChannel * kBytesPerPixel, // bits per pixel
                    width.unsignedLongValue * kBytesPerPixel, // bytes per row
                    colorSpace, bitmapInfo, provider, NULL, false,
                    kCGRenderingIntentDefault);

                UIImage *image = [UIImage imageWithCGImage:cgImage];

                // UIImage takes its own refs, we need to release these here.
                CGImageRelease(cgImage);
                CGColorSpaceRelease(colorSpace);
                CGDataProviderRelease(provider);

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
