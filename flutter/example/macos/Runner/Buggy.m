#import "Buggy.h"

@implementation Buggy

+ (void)throw {
  [NSException raise:@"Raised from Objective-C." format:@"The value %d is the answer", 42];
}

@end
