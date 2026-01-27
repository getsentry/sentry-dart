import 'package:meta/meta.dart';

@internal
class SentrySpanOperations {
  static const String uiLoad = 'ui.load';
  static const String uiTimeToInitialDisplay = 'ui.load.initial_display';
  static const String uiTimeToFullDisplay = 'ui.load.full_display';
  static const String dbSqlQuery = 'db.sql.query';
  static const String dbSqlTransaction = 'db.sql.transaction';
  static const String dbSqlBatch = 'db.sql.batch';
  static const String dbOpen = 'db.open';
  static const String dbClose = 'db.close';
}

@internal
class SentrySpanData {
  static const String dbSystemKey = 'db.system';
  static const String dbNameKey = 'db.name';
  static const String dbSchemaKey = 'db.schema';
  static const String dbTableKey = 'db.table';
  static const String dbUrlKey = 'db.url';
  static const String dbSdkKey = 'db.sdk';
  static const String dbQueryKey = 'db.query';
  static const String dbBodyKey = 'db.body';
  static const String dbOperationKey = 'db.operation';
  static const String httpResponseStatusCodeKey = 'http.response.status_code';
  static const String httpResponseContentLengthKey =
      'http.response_content_length';

  static const String dbSystemSqlite = 'db.sqlite';
  static const String dbSystemPostgresql = 'postgresql';
}

@internal
class SentrySpanDescriptions {
  static const String dbTransaction = 'Transaction';
  static String dbBatch({required List<String> statements}) =>
      'Batch $statements';
  static String dbOpen({required String dbName}) => 'Open database $dbName';
  static String dbClose({required String dbName}) => 'Close database $dbName';
}

/// Semantic attributes for telemetry.
///
/// Not all attributes apply to every telemetry type.
///
/// See https://getsentry.github.io/sentry-conventions/generated/attributes/
/// for more details.
@internal
abstract class SemanticAttributesConstants {
  SemanticAttributesConstants._();

  /// The source of a span, also referred to as transaction source.
  ///
  /// Known values are:  `'custom'`, `'url'`, `'route'`, `'component'`, `'view'`, `'task'`.
  static const sentrySpanSource = 'sentry.span.source';

  /// Attributes that holds the sample rate that was locally applied to a span.
  /// If this attribute is not defined, it means that the span inherited a sampling decision.
  ///
  /// NOTE: Is only defined on root spans.
  static const sentrySampleRate = 'sentry.sample_rate';

  /// Use this attribute to represent the origin of a span.
  static const sentryOrigin = 'sentry.origin';

  /// The release version of the application
  static const sentryRelease = 'sentry.release';

  /// The environment name (e.g., "production", "staging", "development")
  static const sentryEnvironment = 'sentry.environment';

  /// The segment name (e.g., "GET /users")
  static const sentrySegmentName = 'sentry.segment.name';

  /// The span id of the segment that this span belongs to.
  static const sentrySegmentId = 'sentry.segment.id';

  /// The name of the Sentry SDK (e.g., "sentry.dart.flutter")
  static const sentrySdkName = 'sentry.sdk.name';

  /// The version of the Sentry SDK
  static const sentrySdkVersion = 'sentry.sdk.version';

  /// The replay ID.
  static const sentryReplayId = 'sentry.replay_id';

  /// Whether the replay is buffering (onErrorSampleRate).
  static const sentryInternalReplayIsBuffering =
      'sentry._internal.replay_is_buffering';

  /// The user ID (gated by `sendDefaultPii`).
  static const userId = 'user.id';

  /// The user email (gated by `sendDefaultPii`).
  static const userEmail = 'user.email';

  /// The user IP address (gated by `sendDefaultPii`).
  static const userIpAddress = 'user.ip_address';

  /// The user username (gated by `sendDefaultPii`).
  static const userName = 'user.name';

  /// The operating system name.
  static const osName = 'os.name';

  /// The operating system version.
  static const osVersion = 'os.version';

  /// The device brand (e.g., "Apple", "Samsung").
  static const deviceBrand = 'device.brand';

  /// The device model identifier (e.g., "iPhone14,2").
  static const deviceModel = 'device.model';

  /// The device family (e.g., "iOS", "Android").
  static const deviceFamily = 'device.family';
}
