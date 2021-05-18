#import <Foundation/Foundation.h>
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

/* WARNING: This interface mirrors the cocoa SDK to access internal API.
 * If signatures change in the cocoa sdk, this will break and we won't get a warning from the compiler.
 */
@interface SentrySerialization

+ (SentryEnvelope *_Nullable)envelopeWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
