import '../protocol.dart';

/// The debug meta interface carries debug information for processing errors and crash reports.
class DebugMeta {
  /// An object describing the system SDK.
  final SdkInfo sdk;

  final List<DebugImage> _images;

  /// An immutable list of dynamic libraries loaded into the process (see below).
  List<DebugImage> get images => List.unmodifiable(_images);

  DebugMeta({this.sdk, List<DebugImage> images}) : _images = images;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (sdk != null) {
      json['sdk_info'] = sdk.toJson();
    }

    if (_images != null && _images.isNotEmpty) {
      json['images'] = _images.map((e) => e.toJson());
    }

    return json;
  }

  DebugMeta copyWith({SdkVersion sdk, List<DebugImage> images}) =>
      DebugMeta(sdk: sdk ?? this.sdk, images: images ?? _images);
}
