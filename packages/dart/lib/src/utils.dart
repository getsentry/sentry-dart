// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

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

/// A type-safe helper for applying transformations to [FutureOr] values.
///
/// Applies [onValue] to [value] regardless of whether it is a [Future] or
/// synchronous value. If [value] is a [Future], the transformation is applied
/// asynchronously via [Future.then]. Otherwise, the transformation is applied
/// immediately.
///
/// This utility simplifies code that needs to handle both synchronous and
/// asynchronous execution paths uniformly.
@internal
FutureOr<R> futureOrThen<T, R>(
  FutureOr<T> value,
  FutureOr<R> Function(T) onValue,
) =>
    value is Future<T> ? value.then(onValue) : onValue(value);
