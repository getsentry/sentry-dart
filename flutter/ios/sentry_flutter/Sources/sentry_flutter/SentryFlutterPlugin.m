#import "include/SentryFlutterPlugin.h"

// TODO Check if this kind of import is required for cocoapods

//#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
//#import <sentry_flutter/sentry_flutter-Swift.h>
//#else
//// Support project import fallback if the generated compatibility header
//// is not copied when this plugin is created as a library.
//// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
//#import "sentry_flutter-Swift.h"
//#endif

@import sentry_flutter_swift;

@implementation SentryFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SentryFlutterPluginApple registerWithRegistrar:registrar];
}
@end
