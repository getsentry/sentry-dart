// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  runTest(gzip: gzip);
}
