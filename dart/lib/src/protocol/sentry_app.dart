import 'package:meta/meta.dart';

/// App context describes the application.
///
/// As opposed to the runtime, this is the actual application that was
/// running and carries metadata about the current session.
@immutable
class SentryApp {
  static const type = 'app';

  const SentryApp({
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
  });

  /// Human readable application name, as it appears on the platform.
  final String? name;

  /// Human readable application version, as it appears on the platform.
  final String? version;

  /// Version-independent application identifier, often a dotted bundle ID.
  final String? identifier;

  /// Internal build identifier, as it appears on the platform.
  final String? build;

  /// String identifying the kind of build, e.g. `testflight`.
  final String? buildType;

  /// When the application was started by the user.
  final DateTime? startTime;

  /// Application specific device identifier.
  final String? deviceAppHash;

  /// Amount of memory used by the application in bytes.
  final int? appMemory;

  /// A flag indicating whether the app is in foreground or not.
  /// An app is in foreground when it's visible to the user.
  final bool? inForeground;

  /// The names of the currently visible views.
  final List<String>? viewNames;

  /// The current text scale. Only available on Flutter.
  final double? textScale;

  /// Deserializes a [SentryApp] from JSON [Map].
  factory SentryApp.fromJson(Map<String, dynamic> data) {
    final viewNamesJson = data['view_names'] as List<dynamic>?;
    return SentryApp(
      name: data['app_name'],
      version: data['app_version'],
      identifier: data['app_identifier'],
      build: data['app_build'],
      buildType: data['build_type'],
      startTime: data['app_start_time'] != null
          ? DateTime.tryParse(data['app_start_time'])
          : null,
      deviceAppHash: data['device_app_hash'],
      appMemory: data['app_memory'],
      inForeground: data['in_foreground'],
      viewNames: viewNamesJson?.map((e) => e as String).toList(),
      textScale: data['text_scale'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
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
      );

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
      );
}
