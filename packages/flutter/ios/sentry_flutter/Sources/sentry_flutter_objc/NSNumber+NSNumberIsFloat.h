// NOTE: We can remove this file until we update to an objective_c version that has this fix:
// https://github.com/dart-lang/native/pull/2581

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNumber (NSNumberIsFloat)
@property (readonly) bool isFloat;
@end

NS_ASSUME_NONNULL_END


