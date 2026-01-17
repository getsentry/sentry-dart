import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// An object describing the system SDK.
class SdkInfo {
  String? sdkName;
  int? versionMajor;
  int? versionMinor;
  int? versionPatchlevel;

  @internal
  final Map<String, dynamic>? unknown;

  SdkInfo({
    this.sdkName,
    this.versionMajor,
    this.versionMinor,
    this.versionPatchlevel,
    this.unknown,
  });

  /// Deserializes a [SdkInfo] from JSON [Map].
  factory SdkInfo.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SdkInfo(
      sdkName: json.getValueOrNull('sdk_name'),
      versionMajor: json.getValueOrNull('version_major'),
      versionMinor: json.getValueOrNull('version_minor'),
      versionPatchlevel: json.getValueOrNull('version_patchlevel'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (sdkName != null) 'sdk_name': sdkName,
      if (versionMajor != null) 'version_major': versionMajor,
      if (versionMinor != null) 'version_minor': versionMinor,
      if (versionPatchlevel != null) 'version_patchlevel': versionPatchlevel,
    };
  }

  @Deprecated('Assign values directly to the instance.')
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
