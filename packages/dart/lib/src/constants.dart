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
  static const String uiActionClick = 'ui.action.click';
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

  /// The operation name of a span.
  static const sentryOp = 'sentry.op';

  /// Whether the replay is buffering (onErrorSampleRate).
  static const sentryInternalReplayIsBuffering =
      'sentry._internal.replay_is_buffering';

  /// Internal build identifier, as it appears on the platform.
  static const appBuild = 'app.build';

  /// Version-independent application identifier, often a dotted bundle ID.
  static const appIdentifier = 'app.identifier';

  /// Human readable application name, as it appears on the platform.
  static const appName = 'app.name';

  /// Formatted UTC timestamp when the user started the application.
  static const appStartTime = 'app.start_time';

  /// Human readable application version, as it appears on the platform.
  static const appVersion = 'app.version';

  /// Whether the application is currently in the foreground.
  static const appInForeground = 'app.in_foreground';

  /// Whether the application uses split APKs (Android).
  static const appIsSplitApks = 'app.is_split_apks';

  /// The granted status of an application permission, where [permissionName]
  /// is the permission name (e.g., "internet_access").
  static String appPermission(String permissionName) =>
      'app.permissions.$permissionName';

  /// The names of the active views or fragments in the application.
  static const appViewNames = 'app.view_names';

  // Deprecated app attributes - use the non-prefixed versions above.

  /// Deprecated: use [appBuild] instead.
  static const appAppBuild = 'app.app_build';

  /// Deprecated: use [appIdentifier] instead.
  static const appAppIdentifier = 'app.app_identifier';

  /// Deprecated: use [appName] instead.
  static const appAppName = 'app.app_name';

  /// Deprecated: use [appStartTime] instead.
  static const appAppStartTime = 'app.app_start_time';

  /// Deprecated: use [appVersion] instead.
  static const appAppVersion = 'app.app_version';

  /// The user ID.
  /// Users are always manually set and never automatically inferred,
  /// therefore this is not gated by `sendDefaultPii`.
  static const userId = 'user.id';

  /// The user email.
  /// Users are always manually set and never automatically inferred,
  /// therefore this is not gated by `sendDefaultPii`.
  static const userEmail = 'user.email';

  /// The user username.
  /// Users are always manually set and never automatically inferred,
  /// therefore this is not gated by `sendDefaultPii`.
  static const userName = 'user.name';

  /// The operating system name.
  static const osName = 'os.name';

  /// The operating system version.
  static const osVersion = 'os.version';

  /// The build ID of the operating system.
  static const osBuildId = 'os.build_id';

  /// Independent kernel version string, typically from uname.
  static const osKernelVersion = 'os.kernel_version';

  /// Unprocessed OS description string.
  static const osRawDescription = 'os.raw_description';

  /// Whether the OS has been jailbroken or rooted.
  static const osRooted = 'os.rooted';

  /// Whether the OS runs in dark or light mode.
  static const osTheme = 'os.theme';

  // Deprecated OS attributes - use the replacements above.

  /// Deprecated: use [osBuildId] instead.
  static const osBuild = 'os.build';

  /// Battery level as a percentage (0-100).
  static const deviceBatteryLevel = 'device.battery_level';

  /// Battery temperature in Celsius.
  static const deviceBatteryTemperature = 'device.battery_temperature';

  /// Formatted UTC timestamp of when the system was booted.
  static const deviceBootTime = 'device.boot_time';

  /// The device brand (e.g., "Apple", "Samsung").
  static const deviceBrand = 'device.brand';

  /// Whether the device was charging.
  static const deviceCharging = 'device.charging';

  /// Chipset of the device.
  static const deviceChipset = 'device.chipset';

  /// Device classification (e.g., low, medium, high), typically inferred by Relay.
  static const deviceClass = 'device.class';

  /// Internet connection type currently used by the device.
  /// Deprecated: use [networkConnectionType] instead.
  static const deviceConnectionType = 'device.connection_type';

  /// Description of the device CPU.
  static const deviceCpuDescription = 'device.cpu_description';

  /// External storage free size in bytes.
  static const deviceExternalFreeStorage = 'device.external_free_storage';

  /// External storage total size in bytes.
  static const deviceExternalStorageSize = 'device.external_storage_size';

  /// The device family (e.g., "iOS", "Android").
  static const deviceFamily = 'device.family';

  /// Free system memory in bytes.
  static const deviceFreeMemory = 'device.free_memory';

  /// Free device storage in bytes.
  static const deviceFreeStorage = 'device.free_storage';

  /// Unique device identifier.
  static const deviceId = 'device.id';

  /// Whether the device was low on memory.
  static const deviceLowMemory = 'device.low_memory';

  /// Manufacturer of the device.
  static const deviceManufacturer = 'device.manufacturer';

  /// Total system memory in bytes.
  static const deviceMemorySize = 'device.memory_size';

  /// The device model identifier (e.g., "iPhone14,2").
  static const deviceModel = 'device.model';

  /// Internal hardware revision to identify the device exactly.
  static const deviceModelId = 'device.model_id';

  /// User-assigned device name (mobile) or hostname (server/desktop).
  static const deviceName = 'device.name';

  /// Whether the device was online.
  static const deviceOnline = 'device.online';

  /// Device orientation (portrait or landscape).
  static const deviceOrientation = 'device.orientation';

  /// Number of logical processors.
  static const deviceProcessorCount = 'device.processor_count';

  /// Processor frequency in MHz.
  static const deviceProcessorFrequency = 'device.processor_frequency';

  /// Screen density of the device.
  static const deviceScreenDensity = 'device.screen_density';

  /// Screen density in dots-per-inch (DPI).
  static const deviceScreenDpi = 'device.screen_dpi';

  /// Height of the device screen in pixels.
  static const deviceScreenHeightPixels = 'device.screen_height_pixels';

  /// Width of the device screen in pixels.
  static const deviceScreenWidthPixels = 'device.screen_width_pixels';

  /// Whether the device is a simulator or actual device.
  static const deviceSimulator = 'device.simulator';

  /// Total device storage in bytes.
  static const deviceStorageSize = 'device.storage_size';

  /// Thermal state (nominal, fair, serious, critical).
  static const deviceThermalState = 'device.thermal_state';

  /// Memory usable for the app in bytes.
  static const deviceUsableMemory = 'device.usable_memory';

  /// The CPU architectures of the device.
  static const deviceArchs = 'device.archs';

  // Deprecated device attributes - use the replacements below.

  /// Deprecated: use [cultureLocale] instead.
  static const deviceLocale = 'device.locale';

  /// Deprecated: use [cultureTimezone] instead.
  static const deviceTimezone = 'device.timezone';

  // Culture attributes

  /// The locale of the device.
  static const cultureLocale = 'culture.locale';

  /// The timezone of the device.
  static const cultureTimezone = 'culture.timezone';

  // Network attributes

  /// The internet connection type currently used by the host.
  static const networkConnectionType = 'network.connection.type';

  /// The number of total frames rendered during the lifetime of the span.
  static const framesTotal = 'frames.total';

  /// The number of slow frames rendered during the lifetime of the span.
  static const framesSlow = 'frames.slow';

  /// The number of frozen frames rendered during the lifetime of the span.
  static const framesFrozen = 'frames.frozen';

  /// The sum of all delayed frame durations in seconds during the lifetime of the span.
  /// For more information see [frames delay](https://develop.sentry.dev/sdk/performance/frames-delay/).
  static const framesDelay = 'frames.delay';

  /// The HTTP request method (e.g., "GET", "POST").
  static const httpRequestMethod = 'http.request.method';

  /// The URL of an HTTP request.
  // TODO: this needs to be updated to use the new url attributes e.g url.full, etc...
  static const url = 'url';

  /// The HTTP query string (e.g., "foo=bar").
  static const httpQuery = 'http.query';

  /// The HTTP fragment (e.g., "section").
  static const httpFragment = 'http.fragment';

  /// The HTTP response status code.
  static const httpResponseStatusCode = 'http.response.status_code';

  /// The HTTP response content length.
  static const httpResponseContentLength = 'http.response_content_length';

  /// The database system identifier.
  // TODO: deprecated, needs to be replaced later by db.system.name
  static const dbSystem = 'db.system';

  /// The database name.
  // TODO: deprecated, needs to be replaced later by db.namespace
  static const dbName = 'db.name';
}
