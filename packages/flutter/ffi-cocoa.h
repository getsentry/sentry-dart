#include <stdint.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryFlutterPlugin : NSObject

+ (uint64_t)startProfilerForTrace:(NSString *)traceId;

@end

NS_ASSUME_NONNULL_END
