import 'package:meta/meta.dart';

import '../constants.dart';
import 'access_aware_map.dart';
import 'sentry_attribute.dart';

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
  factory SentryApp.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryApp(
      name: json.readString('app_name'),
      version: json.readString('app_version'),
      identifier: json.readString('app_identifier'),
      build: json.readString('app_build'),
      buildType: json.readString('build_type'),
      startTime: json.readDateTime('app_start_time'),
      deviceAppHash: json.readString('device_app_hash'),
      appMemory: json.readInt('app_memory'),
      inForeground: json.readBool('in_foreground'),
      viewNames: json.readStringList('view_names'),
      textScale: json.readDouble('text_scale'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'app_name': ?name,
      'app_version': ?version,
      'app_identifier': ?identifier,
      'app_build': ?build,
      'build_type': ?buildType,
      'app_start_time': ?startTime?.toIso8601String(),
      'device_app_hash': ?deviceAppHash,
      'app_memory': ?appMemory,
      'in_foreground': ?inForeground,
      if (viewNames != null && viewNames!.isNotEmpty) 'view_names': viewNames!,
      'text_scale': ?textScale,
    };
  }

  /// A map of stable semantic span attributes derived from this app.
  ///
  /// Only fields with a defined stable key in [SemanticAttributesConstants]
  /// are included. Intended for span v2 attributes; error and transaction
  /// payloads continue to use [toJson].
  @internal
  Map<String, SentryAttribute> toAttributes() {
    final attributes = <String, SentryAttribute>{};
    final name = this.name;
    if (name != null) {
      attributes[SemanticAttributesConstants.appName] = SentryAttribute.string(
        name,
      );
    }
    final version = this.version;
    if (version != null) {
      attributes[SemanticAttributesConstants.appVersion] =
          SentryAttribute.string(version);
    }
    final identifier = this.identifier;
    if (identifier != null) {
      attributes[SemanticAttributesConstants.appIdentifier] =
          SentryAttribute.string(identifier);
    }
    final build = this.build;
    if (build != null) {
      attributes[SemanticAttributesConstants.appBuild] = SentryAttribute.string(
        build,
      );
    }
    final startTime = this.startTime;
    if (startTime != null) {
      attributes[SemanticAttributesConstants.appStartTime] =
          SentryAttribute.string(startTime.toIso8601String());
    }
    final inForeground = this.inForeground;
    if (inForeground != null) {
      attributes[SemanticAttributesConstants.appInForeground] =
          SentryAttribute.bool(inForeground);
    }
    return attributes;
  }
}
