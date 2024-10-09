// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:meta/meta.dart';

import '../sentry.dart';

/// Sentry does not take a timezone and instead expects the date-time to be
/// submitted in UTC timezone.
@internal
DateTime getUtcDateTime() => DateTime.now().toUtc();

/// Formats a Date as ISO8601 and UTC with millis precision
@internal
String formatDateAsIso8601WithMillisPrecision(DateTime date) {
  var iso = date.toIso8601String();
  final millisecondSeparatorIndex = iso.lastIndexOf('.');
  if (millisecondSeparatorIndex != -1) {
    // + 4 for millis precision
    iso = iso.substring(0, millisecondSeparatorIndex + 4);
  }
  // appends Z because the substring removed it
  return '${iso}Z';
}

@internal
final utf8JsonEncoder = JsonUtf8Encoder(null, jsonSerializationFallback, null);

@internal
Object? jsonSerializationFallback(Object? nonEncodable) {
  if (nonEncodable == null) {
    return null;
  }
  return nonEncodable.toString();
}
