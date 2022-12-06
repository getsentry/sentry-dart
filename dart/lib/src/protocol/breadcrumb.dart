import 'package:meta/meta.dart';

import '../utils.dart';
import '../protocol.dart';

/// Structed data to describe more information pior to the event captured.
/// See `Sentry.captureEvent()`.
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
/// * https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
@immutable
class Breadcrumb {
  /// Creates a breadcrumb that can be attached to an [SentryEvent].
  Breadcrumb({
    this.message,
    DateTime? timestamp,
    this.category,
    this.data,
    SentryLevel? level,
    this.type,
  })  : timestamp = timestamp ?? getUtcDateTime(),
        level = level ?? SentryLevel.info;

  factory Breadcrumb.http({
    required Uri url,
    required String method,
    int? statusCode,
    String? reason,
    Duration? requestDuration,
    SentryLevel? level,
    DateTime? timestamp,

    // Size of the request body in bytes
    int? requestBodySize,

    // Size of the response body in bytes
    int? responseBodySize,
  }) {
    return Breadcrumb(
      type: 'http',
      category: 'http',
      level: level,
      timestamp: timestamp,
      data: {
        'url': url.toString(),
        'method': method,
        if (statusCode != null) 'status_code': statusCode,
        if (reason != null) 'reason': reason,
        if (requestDuration != null) 'duration': requestDuration.toString(),
        if (requestBodySize != null) 'request_body_size': requestBodySize,
        if (responseBodySize != null) 'response_body_size': responseBodySize,
      },
    );
  }

  factory Breadcrumb.console({
    String? message,
    SentryLevel? level,
    DateTime? timestamp,
    Map<String, dynamic>? data,
  }) {
    return Breadcrumb(
      message: message,
      level: level,
      category: 'console',
      type: 'debug',
      timestamp: timestamp,
      data: data,
    );
  }

  factory Breadcrumb.userInteraction({
    String? message,
    SentryLevel? level,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    required String subCategory,
    String? viewId,
    String? viewClass,
  }) {
    final newData = data ?? {};
    if (viewId != null) {
      newData['view.id'] = viewId;
    }
    if (viewClass != null) {
      newData['view.class'] = viewClass;
    }

    return Breadcrumb(
      message: message,
      level: level,
      category: 'ui.$subCategory',
      type: 'user',
      timestamp: timestamp,
      data: newData,
    );
  }

  /// Describes the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final String? message;

  /// A dot-separated string describing the source of the breadcrumb, e.g. "ui.click".
  ///
  /// This field is optional and may be set to null.
  final String? category;

  /// Data associated with the breadcrumb.
  ///
  /// The contents depend on the [type] of breadcrumb.
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/#breadcrumb-types
  final Map<String, dynamic>? data;

  /// Severity of the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final SentryLevel? level;

  /// Describes what type of breadcrumb this is.
  ///
  /// Possible values: "default", "http", "navigation".
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/#breadcrumb-types
  final String? type;

  /// The time the breadcrumb was recorded.
  ///
  /// This field is required, it must not be null.
  ///
  /// The value is submitted to Sentry with second precision.
  final DateTime timestamp;

  /// Deserializes a [Breadcrumb] from JSON [Map].
  factory Breadcrumb.fromJson(Map<String, dynamic> json) {
    final levelName = json['level'];
    final timestamp = json['timestamp'];

    var data = json['data'];
    if (data != null) {
      data = Map<String, dynamic>.from(data as Map);
    }

    return Breadcrumb(
      timestamp: timestamp != null ? DateTime.tryParse(timestamp) : null,
      message: json['message'],
      category: json['category'],
      data: data,
      level: levelName != null ? SentryLevel.fromName(levelName) : null,
      type: json['type'],
    );
  }

  /// Converts this breadcrumb to a map that can be serialized to JSON according
  /// to the Sentry protocol.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
      if (message != null) 'message': message,
      if (category != null) 'category': category,
      if (data?.isNotEmpty ?? false) 'data': data,
      if (level != null) 'level': level!.name,
      if (type != null) 'type': type,
    };
  }

  Breadcrumb copyWith({
    String? message,
    String? category,
    Map<String, dynamic>? data,
    SentryLevel? level,
    String? type,
    DateTime? timestamp,
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
