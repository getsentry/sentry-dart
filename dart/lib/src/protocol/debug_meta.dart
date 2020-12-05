import '../protocol.dart';

/// The debug meta interface carries debug information for processing errors and crash reports.
class DebugMeta {
  /// An object describing the system SDK.
  final SdkInfo sdk;

  final List<DebugImage> _images;

  /// The immutable list of debug images contains all dynamic libraries loaded
  /// into the process and their memory addresses.
  /// Instruction addresses in the Stack Trace are mapped into the list of debug
  /// images in order to retrieve debug files for symbolication.
  List<DebugImage> get images => List.unmodifiable(_images);

  DebugMeta({this.sdk, List<DebugImage> images})
      : _images = images != null ? List.from(images) : null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    Map<String, dynamic> sdkInfo;
    if (sdk != null && (sdkInfo = sdk.toJson()).isNotEmpty) {
      json['sdk_info'] = sdkInfo;
    }

    if (_images != null && _images.isNotEmpty) {
      json['images'] = _images
          .map((e) => e.toJson())
          .where((element) => element.isNotEmpty)
          .toList(growable: false);
    }

    return json;
  }

  DebugMeta copyWith({SdkVersion sdk, List<DebugImage> images}) =>
      DebugMeta(sdk: sdk ?? this.sdk, images: images ?? _images);
}
