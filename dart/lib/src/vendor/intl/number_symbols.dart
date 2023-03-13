// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library number_symbols;

// Suppress naming issues as changes would be breaking.
// ignore_for_file: non_constant_identifier_names

class NumberSymbols {
  final String DECIMAL_SEP,
      ZERO_DIGIT,
      NAN;

  const NumberSymbols(
      {required this.DECIMAL_SEP,
      required this.ZERO_DIGIT,
      required this.NAN});
}
