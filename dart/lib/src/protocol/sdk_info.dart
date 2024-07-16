import 'package:meta/meta.dart';

import 'unknown.dart';

/// An object describing the system SDK.
@immutable
class SdkInfo {
  final String? sdkName;
  final int? versionMajor;
  final int? versionMinor;
  final int? versionPatchlevel;

  @internal
  final Map<String, dynamic>? unknown;

  const SdkInfo({
    this.sdkName,
    this.versionMajor,
    this.versionMinor,
    this.versionPatchlevel,
    this.unknown,
  });

  /// Deserializes a [SdkInfo] from JSON [Map].
  factory SdkInfo.fromJson(Map<String, dynamic> json) {
    return SdkInfo(
      sdkName: json['sdk_name'],
      versionMajor: json['version_major'],
      versionMinor: json['version_minor'],
      versionPatchlevel: json['version_patchlevel'],
      unknown: unknownFrom(json, {
        'sdk_name',
        'version_major',
        'version_minor',
        'version_patchlevel',
      }),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      if (sdkName != null) 'sdk_name': sdkName,
      if (versionMajor != null) 'version_major': versionMajor,
      if (versionMinor != null) 'version_minor': versionMinor,
      if (versionPatchlevel != null) 'version_patchlevel': versionPatchlevel,
      ...?unknown,
    };
  }

  SdkInfo copyWith({
    String? sdkName,
    int? versionMajor,
    int? versionMinor,
    int? versionPatchlevel,
  }) =>
      SdkInfo(
        sdkName: sdkName ?? this.sdkName,
        versionMajor: versionMajor ?? this.versionMajor,
        versionMinor: versionMinor ?? this.versionMinor,
        versionPatchlevel: versionPatchlevel ?? this.versionPatchlevel,
        unknown: unknown,
      );
}
