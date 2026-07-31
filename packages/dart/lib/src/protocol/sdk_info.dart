import 'package:meta/meta.dart';

import 'access_aware_map.dart';

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
  factory SdkInfo.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SdkInfo(
      sdkName: json.readString('sdk_name'),
      versionMajor: json.readInt('version_major'),
      versionMinor: json.readInt('version_minor'),
      versionPatchlevel: json.readInt('version_patchlevel'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'sdk_name': ?sdkName,
      'version_major': ?versionMajor,
      'version_minor': ?versionMinor,
      'version_patchlevel': ?versionPatchlevel,
    };
  }
}
