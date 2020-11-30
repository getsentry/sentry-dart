import '../../sentry.dart';

/// An object describing the system SDK.
class SdkInfo {
  final String sdkName;
  final int versionMajor;
  final int versionMinor;
  final int versionPatchlevel;

  SdkInfo({
    this.sdkName,
    this.versionMajor,
    this.versionMinor,
    this.versionPatchlevel,
  });

  /// Creates a SdkInfo out of a SdkVersion
  factory SdkInfo.fromSdkVersion(SdkVersion sdkVersion) {
    var name;
    var major;
    var minor;
    var patch;
    try {
      name = sdkVersion.name;
      final versions = sdkVersion.version.split('.');
      final fullPatch = versions[2];
      // because of prereleases (eg -alpha) sufix
      final singlePatch = fullPatch.split('-');

      major = int.parse(versions[0]);
      minor = int.parse(versions[1]);
      patch = int.parse(singlePatch[0]);
    } catch (error) {
      // something is wrong but keep going
    }

    return SdkInfo(
        sdkName: name,
        versionMajor: major,
        versionMinor: minor,
        versionPatchlevel: patch);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (sdkName != null) {
      json['sdk_name'] = sdkName;
    }

    if (versionMajor != null) {
      json['version_major'] = versionMajor;
    }

    if (versionMinor != null) {
      json['version_minor'] = versionMinor;
    }

    if (versionPatchlevel != null) {
      json['version_patchlevel'] = versionPatchlevel;
    }

    return json;
  }

  SdkInfo copyWith({
    String sdkName,
    int versionMajor,
    int versionMinor,
    int versionPatchlevel,
  }) =>
      SdkInfo(
        sdkName: sdkName ?? this.sdkName,
        versionMajor: versionMajor ?? this.versionMajor,
        versionMinor: versionMinor ?? this.versionMinor,
        versionPatchlevel: versionPatchlevel ?? this.versionPatchlevel,
      );
}
