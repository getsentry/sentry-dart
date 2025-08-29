// NOTE: We can remove this file until we update to an objective_c version that has this fix:
// https://github.com/dart-lang/native/pull/2581

#import "NSNumber+NSNumberIsFloat.h"

@implementation NSNumber (NSNumberIsFloat)
- (bool)isFloat {
  const char *t = [self objCType];
  return strcmp(t, @encode(float)) == 0 || strcmp(t, @encode(double)) == 0;
}
@end


