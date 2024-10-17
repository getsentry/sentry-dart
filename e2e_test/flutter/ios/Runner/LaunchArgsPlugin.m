#import "LaunchArgsPlugin.h"

@implementation LaunchArgsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
            methodChannelWithName:@"launchargs"
                  binaryMessenger:[registrar messenger]];
    LaunchArgsPlugin* instance = [[LaunchArgsPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"args" isEqualToString:call.method]) {
        result([[NSProcessInfo processInfo] arguments]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end