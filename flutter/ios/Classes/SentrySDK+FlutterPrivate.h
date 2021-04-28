#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (FlutterPrivate)

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END