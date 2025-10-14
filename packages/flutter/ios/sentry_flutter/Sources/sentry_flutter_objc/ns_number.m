// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Note: this file is needed for a workaround regarding the following Dart objective_c issue:
// https://github.com/dart-lang/native/pull/2581

#import "ns_number.h"

@implementation NSNumber (NSNumberIsFloat)
-(bool)isFloat {
    const char *t = [self objCType];
    return strcmp(t, @encode(float)) == 0 || strcmp(t, @encode(double)) == 0;
}
@end
