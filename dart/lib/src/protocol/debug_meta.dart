import 'package:meta/meta.dart';

import '../protocol.dart';
import 'access_aware_map.dart';

/// The debug meta interface carries debug information for processing errors and crash reports.
@immutable
class DebugMeta {
  /// An object describing the system SDK.
  final SdkInfo? sdk;

  final List<DebugImage>? _images;

  /// The immutable list of debug images contains all dynamic libraries loaded
  /// into the process and their memory addresses.
  /// Instruction addresses in the Stack Trace are mapped into the list of debug
  /// images in order to retrieve debug files for symbolication.
  List<DebugImage> get images => List.unmodifiable(_images ?? const []);

  DebugMeta({this.sdk, List<DebugImage>? images, this.unknown})
      : _images = images;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [DebugMeta] from JSON [Map].
  factory DebugMeta.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final sdkInfoJson = json['sdk_info'];
    final debugImagesJson = json['images'] as List<dynamic>?;
    return DebugMeta(
      sdk: sdkInfoJson != null ? SdkInfo.fromJson(sdkInfoJson) : null,
      images: debugImagesJson
          ?.map((debugImageJson) =>
              DebugImage.fromJson(debugImageJson as Map<String, dynamic>))
          .toList(),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final sdkInfo = sdk?.toJson();
    return {
      ...?unknown,
      if (sdkInfo?.isNotEmpty ?? false) 'sdk_info': sdkInfo,
      if (_images?.isNotEmpty ?? false)
        'images': _images!
            .map((e) => e.toJson())
            .where((element) => element.isNotEmpty)
            .toList(growable: false),
    };
  }

  DebugMeta copyWith({
    SdkInfo? sdk,
    List<DebugImage>? images,
  }) =>
      DebugMeta(
        sdk: sdk ?? this.sdk,
        images: images ?? _images,
        unknown: unknown,
      );
}
