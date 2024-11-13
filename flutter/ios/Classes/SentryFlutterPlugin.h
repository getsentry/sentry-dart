#if TARGET_OS_IPHONE
    #import <Flutter/Flutter.h>
#else
    #import <FlutterMacOS/FlutterMacOS.h>
#endif

#import <Sentry/SentryDebugImageProvider.h>

@interface SentryFlutterPlugin : NSObject<FlutterPlugin>
@end
