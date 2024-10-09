#if TARGET_OS_IPHONE
    #import <Flutter/Flutter.h>
#else
    #import <FlutterMacOS/FlutterMacOS.h>
#endif

#import <Sentry/SentryDebugImageProvider.h>

@interface SentryFlutterPlugin : NSObject<FlutterPlugin>
@end

@interface SentryDebugImageProvider ()
- (NSArray<SentryDebugMeta *> * _Nonnull)getDebugImagesForAddresses:(NSSet<NSString *> * _Nonnull)addresses isCrash:(BOOL)isCrash;
@end
