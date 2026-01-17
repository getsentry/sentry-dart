import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// App context describes the application.
///
/// As opposed to the runtime, this is the actual application that was
/// running and carries metadata about the current session.
class SentryApp {
  static const type = 'app';

  SentryApp({
    this.name,
    this.version,
    this.identifier,
    this.build,
    this.buildType,
    this.startTime,
    this.deviceAppHash,
    this.appMemory,
    this.inForeground,
    this.viewNames,
    this.textScale,
    this.unknown,
  });

  /// Human readable application name, as it appears on the platform.
  String? name;

  /// Human readable application version, as it appears on the platform.
  String? version;

  /// Version-independent application identifier, often a dotted bundle ID.
  String? identifier;

  /// Internal build identifier, as it appears on the platform.
  String? build;

  /// String identifying the kind of build, e.g. `testflight`.
  String? buildType;

  /// When the application was started by the user.
  DateTime? startTime;

  /// Application specific device identifier.
  String? deviceAppHash;

  /// Amount of memory used by the application in bytes.
  int? appMemory;

  /// A flag indicating whether the app is in foreground or not.
  /// An app is in foreground when it's visible to the user.
  bool? inForeground;

  /// The names of the currently visible views.
  List<String>? viewNames;

  /// The current text scale. Only available on Flutter.
  double? textScale;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryApp] from JSON [Map].
  factory SentryApp.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final viewNamesJson = json.getValueOrNull<List<dynamic>>('view_names');
    return SentryApp(
      name: json.getValueOrNull('app_name'),
      version: json.getValueOrNull('app_version'),
      identifier: json.getValueOrNull('app_identifier'),
      build: json.getValueOrNull('app_build'),
      buildType: json.getValueOrNull('build_type'),
      startTime: json.getValueOrNull('app_start_time'),
      deviceAppHash: json.getValueOrNull('device_app_hash'),
      appMemory: json.getValueOrNull('app_memory'),
      inForeground: json.getValueOrNull('in_foreground'),
      viewNames: viewNamesJson?.map((e) => e as String).toList(),
      textScale: json.getValueOrNull('text_scale'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'app_name': name!,
      if (version != null) 'app_version': version!,
      if (identifier != null) 'app_identifier': identifier!,
      if (build != null) 'app_build': build!,
      if (buildType != null) 'build_type': buildType!,
      if (startTime != null) 'app_start_time': startTime!.toIso8601String(),
      if (deviceAppHash != null) 'device_app_hash': deviceAppHash!,
      if (appMemory != null) 'app_memory': appMemory!,
      if (inForeground != null) 'in_foreground': inForeground!,
      if (viewNames != null && viewNames!.isNotEmpty) 'view_names': viewNames!,
      if (textScale != null) 'text_scale': textScale!,
    };
  }

  @Deprecated('Will be removed in a future version.')
  SentryApp clone() => SentryApp(
        name: name,
        version: version,
        identifier: identifier,
        build: build,
        buildType: buildType,
        startTime: startTime,
        deviceAppHash: deviceAppHash,
        appMemory: appMemory,
        inForeground: inForeground,
        viewNames: viewNames,
        textScale: textScale,
        unknown: unknown,
      );

  @Deprecated('Assign values directly to the instance.')
  SentryApp copyWith({
    String? name,
    String? version,
    String? identifier,
    String? build,
    String? buildType,
    DateTime? startTime,
    String? deviceAppHash,
    int? appMemory,
    bool? inForeground,
    List<String>? viewNames,
    double? textScale,
  }) =>
      SentryApp(
        name: name ?? this.name,
        version: version ?? this.version,
        identifier: identifier ?? this.identifier,
        build: build ?? this.build,
        buildType: buildType ?? this.buildType,
        startTime: startTime ?? this.startTime,
        deviceAppHash: deviceAppHash ?? this.deviceAppHash,
        appMemory: appMemory ?? this.appMemory,
        inForeground: inForeground ?? this.inForeground,
        viewNames: viewNames ?? this.viewNames,
        textScale: textScale ?? this.textScale,
        unknown: unknown,
      );
}
