// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Note: this file is needed for a workaround regarding the following Dart objective_c issue:
// https://github.com/dart-lang/native/pull/2581

#ifndef OBJECTIVE_C_SRC_NS_NUMBER_H_
#define OBJECTIVE_C_SRC_NS_NUMBER_H_

#import <Foundation/Foundation.h>

@interface NSNumber (NSNumberIsFloat)
@property (readonly) bool isFloat;
@end

#endif  // OBJECTIVE_C_SRC_NS_NUMBER_H_
