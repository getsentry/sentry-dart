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

@internal
extension SpanAttributeUtils on SentrySpanV2 {
  void addAttributesIfAbsent(Map<String, SentryAttribute> attributes) {
    if (attributes.isEmpty) {
      return;
    }

    final existing = this.attributes;
    for (final entry in attributes.entries) {
      if (!existing.containsKey(entry.key)) {
        setAttribute(entry.key, entry.value);
      }
    }
  }
}

@internal
extension AddAllAbsentX<K, V> on Map<K, V> {
  void addAllIfAbsent(Map<K, V> other) {
    for (final e in other.entries) {
      putIfAbsent(e.key, () => e.value);
    }
  }
}

@internal
extension SentryAttributeFormatting on SentryAttribute {
  /// Formats the attribute value for debug/log output.
  ///
  /// Strings are quoted, numbers and booleans are shown as-is.
  String toFormattedString() {
    switch (type) {
      case 'string':
        if (value is String) {
          return '"$value"';
        }
        break;
      case 'boolean':
        if (value is bool) {
          return value.toString();
        }
        break;
      case 'integer':
        if (value is int) {
          return value.toString();
        }
        break;
      case 'double':
        if (value is double) {
          final doubleValue = value as double;
          // Handle special double values
          if (doubleValue.isNaN || doubleValue.isInfinite) {
            return doubleValue.toString();
          }
          // Ensure doubles always show decimal notation to distinguish from ints
          return doubleValue == doubleValue.toInt()
              ? doubleValue.toStringAsFixed(1)
              : doubleValue.toString();
        }
        break;
    }
    return value.toString();
  }
}

@internal
extension SentryAttributeMapFormatting on Map<String, SentryAttribute> {
  /// Formats attributes as `{key1: value1, key2: value2}`.
  ///
  /// Returns an empty string if the map is empty.
  String toFormattedString() {
    if (isEmpty) return '';
    final attrsStr = entries
        .map((e) => '"${e.key}": ${e.value.toFormattedString()}')
        .join(', ');
    return '{$attrsStr}';
  }
}
