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
