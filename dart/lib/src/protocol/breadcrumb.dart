import 'package:meta/meta.dart';

import '../utils.dart';
import 'sentry_level.dart';

/// Structed data to describe more information pior to the event [captured][Sentry.captureEvent].
///
/// The outgoing JSON representation is:
///
/// ```
/// {
///   "timestamp": 1000
///   "message": "message",
///   "category": "category",
///   "data": {"key": "value"},
///   "level": "info",
///   "type": "default"
/// }
/// ```
/// See also:
/// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/
@immutable
class Breadcrumb {
  /// Creates a breadcrumb that can be attached to an [Event].
  Breadcrumb({
    this.message,
    DateTime timestamp,
    this.category,
    this.data,
    this.level = SentryLevel.info,
    this.type,
  }) : timestamp = timestamp ?? getUtcDateTime();

  /// Describes the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final String message;

  /// A dot-separated string describing the source of the breadcrumb, e.g. "ui.click".
  ///
  /// This field is optional and may be set to null.
  final String category;

  /// Data associated with the breadcrumb.
  ///
  /// The contents depend on the [type] of breadcrumb.
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/#breadcrumb-types
  final Map<String, dynamic> data;

  /// Severity of the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final SentryLevel level;

  /// Describes what type of breadcrumb this is.
  ///
  /// Possible values: "default", "http", "navigation".
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/#breadcrumb-types
  final String type;

  /// The time the breadcrumb was recorded.
  ///
  /// This field is required, it must not be null.
  ///
  /// The value is submitted to Sentry with second precision.
  final DateTime timestamp;

  /// Converts this breadcrumb to a map that can be serialized to JSON according
  /// to the Sentry protocol.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
    };
    if (message != null) {
      json['message'] = message;
    }
    if (category != null) {
      json['category'] = category;
    }
    if (data != null && data.isNotEmpty) {
      json['data'] = data;
    }
    if (level != null) {
      json['level'] = level.name;
    }
    if (type != null) {
      json['type'] = type;
    }
    return json;
  }

  Breadcrumb copyWith({
    String message,
    String category,
    Map<String, dynamic> data,
    SentryLevel level,
    String type,
    DateTime timestamp,
  }) =>
      Breadcrumb(
        message: message ?? this.message,
        category: category ?? this.category,
        data: data ?? this.data,
        level: level ?? this.level,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
      );
}
