#import <Foundation/Foundation.h>

#if __has_include(<sentry_flutter/sentry_flutter-Swift.h>)
#import <sentry_flutter/sentry_flutter-Swift.h>
#else
@interface SentryFlutterPlugin : NSObject
+ (nonnull NSDictionary<NSString *, id> *)loadContexts;
+ (nonnull NSArray<NSDictionary<NSString *, id> *> *)loadDebugImages:(nonnull NSSet<NSString *> *)instructionAddresses;
@end
#endif
