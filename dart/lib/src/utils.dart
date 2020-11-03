// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sentry does not take a timezone and instead expects the date-time to be
/// submitted in UTC timezone.
DateTime getUtcDateTime() => DateTime.now().toUtc();

String formatDateAsIso8601WithSecondPrecision(DateTime date) {
  var iso = date.toIso8601String();
  final millisecondSeparatorIndex = iso.lastIndexOf('.');
  if (millisecondSeparatorIndex != -1) {
    iso = iso.substring(0, millisecondSeparatorIndex);
  }
  return iso;
}

/// helper to detect a browser context
const isWeb = identical(1.0, 1);
