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

/// Features are SDK metadata to help us query SDK usage and analytics internally.
@internal
class SentryFeatures {
  static const String beforeSendEvent = 'beforeSendEvent';
  static const String beforeSendTransaction = 'beforeSendTransaction';
  static const String beforeSendFeedback = 'beforeSendFeedback';
  static const String beforeSendLog = 'beforeSendLog';
  static const String beforeSendMetric = 'beforeSendMetric';
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

  /// The build identifier of the application.
  static const appBuild = 'app.build';

  /// The version-independent application identifier, often a dotted bundle ID.
  static const appIdentifier = 'app.identifier';

  /// The human readable application name, as it appears on the platform.
  static const appName = 'app.name';

  /// The formatted UTC timestamp when the user started the application.
  static const appStartTime = 'app.start_time';

  /// The human readable application version, as it appears on the platform.
  static const appVersion = 'app.version';

  /// Internal build identifier, as it appears on the platform.
  // TODO: deprecated, needs to be replaced later by app.build
  static const appAppBuild = 'app.app_build';

  /// Version-independent application identifier, often a dotted bundle ID.
  // TODO: deprecated, needs to be replaced later by app.identifier
  static const appAppIdentifier = 'app.app_identifier';

  /// Human readable application name, as it appears on the platform.
  // TODO: deprecated, needs to be replaced later by app.name
  static const appAppName = 'app.app_name';

  /// Formatted UTC timestamp when the user started the application.
  // TODO: deprecated, needs to be replaced later by app.start_time
  static const appAppStartTime = 'app.app_start_time';

  /// Human readable application version, as it appears on the platform.
  // TODO: deprecated, needs to be replaced later by app.version
  static const appAppVersion = 'app.app_version';

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

  /// The value of the time to initial display in milliseconds.
  static const appVitalsTtidValue = 'app.vitals.ttid.value';

  /// The value of the time to full display in milliseconds.
  static const appVitalsTtfdValue = 'app.vitals.ttfd.value';

  /// The value of the cold app start in milliseconds.
  /// This will later be replaced by app.vitals.start.value
  static const appVitalsStartColdValue = 'app.vitals.start.cold.value';

  /// The value of the warm app start in milliseconds.
  /// This will later be replaced by app.vitals.start.value
  static const appVitalsStartWarmValue = 'app.vitals.start.warm.value';

  /// The type of the app start. (cold or warm)
  static const appVitalsStartType = 'app.vitals.start.type';

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

  /// The user's IP address.
  static const userIpAddress = 'user.ip_address';

  /// Human readable city name of the user.
  static const userGeoCity = 'user.geo.city';

  /// Two-letter country code (ISO 3166-1 alpha-2) of the user.
  static const userGeoCountryCode = 'user.geo.country_code';

  /// Human readable region name or code of the user.
  static const userGeoRegion = 'user.geo.region';

  /// Subregion of the user (e.g. a continental area).
  static const userGeoSubregion = 'user.geo.subregion';

  /// Subdivision of the user (e.g. state, province).
  static const userGeoSubdivision = 'user.geo.subdivision';

  /// The operating system name.
  static const osName = 'os.name';

  /// The operating system version.
  static const osVersion = 'os.version';

  /// The build ID of the operating system.
  // TODO: deprecated, needs to be replaced later by os.build_id
  static const osBuild = 'os.build';

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
  // TODO: deprecated, needs to be replaced later by network.connection.type
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
  /// Should be used later when relay supports array attributes instead of `device.arch` as it is deprecated.
  static const deviceArchs = 'device.archs';

  /// The locale of the device.
  // TODO: deprecated, needs to be replaced later by culture.locale
  static const deviceLocale = 'device.locale';

  /// The timezone of the device.
  // TODO: deprecated, needs to be replaced later by culture.timezone
  static const deviceTimezone = 'device.timezone';

  /// The calendar of the culture (e.g. `GregorianCalendar`).
  static const cultureCalendar = 'culture.calendar';

  /// Human readable display name of the culture (e.g. `English (United States)`).
  static const cultureDisplayName = 'culture.display_name';

  /// The name identifier of the culture, usually following RFC 4646
  /// (e.g. `en-US` or `pt-BR`).
  static const cultureLocale = 'culture.locale';

  /// Whether the culture uses a 24-hour time format.
  static const cultureIs24HourFormat = 'culture.is_24_hour_format';

  /// The timezone of the culture (e.g. `Europe/Vienna`).
  static const cultureTimezone = 'culture.timezone';

  /// The name of the runtime of this process.
  static const processRuntimeName = 'process.runtime.name';

  /// The version of the runtime of this process.
  static const processRuntimeVersion = 'process.runtime.version';

  /// Additional description about the runtime of the process, for example a
  /// specific vendor customization of the standard runtime.
  static const processRuntimeDescription = 'process.runtime.description';

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

/// Attribute keys emitted by the SDK that are not (yet) codified in
/// [Sentry Conventions](https://getsentry.github.io/sentry-conventions/).
///
/// Values here are considered candidates for promotion to
/// [SemanticAttributesConstants]. Treat them as unstable: names may change
/// once a convention is adopted. Add entries with a doc comment explaining
/// why they exist and what canonical attribute (if any) should replace them.
@internal
abstract class ProposedSemanticAttributes {
  ProposedSemanticAttributes._();

  /// The Flutter SDK version used to compile the app (e.g. `3.24.0`).
  ///
  /// Emitted separately from [SemanticAttributesConstants.processRuntimeName]
  /// because `process.runtime.*` describes the process runtime (Dart VM), not
  /// the framework on top of it.
  static const flutterVersion = 'flutter.version';

  /// The Flutter release channel used to compile the app
  /// (e.g. `stable`, `beta`, `master`).
  static const flutterChannel = 'flutter.channel';
}
