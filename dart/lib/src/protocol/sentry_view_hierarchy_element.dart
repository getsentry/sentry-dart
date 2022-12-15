import 'package:meta/meta.dart';

@immutable
class SentryViewHierarchyElement {
  SentryViewHierarchyElement(
    this.type, {
    this.depth,
    this.identifier,
    this.width,
    this.height,
    this.x,
    this.y,
    this.z,
    this.visible,
    this.alpha,
    this.extra,
  });

  final String type;
  final int? depth;
  final String? identifier;
  final List<SentryViewHierarchyElement> children = [];
  final double? width;
  final double? height;
  final double? x;
  final double? y;
  final double? z;
  final bool? visible;
  final double? alpha;
  final Map<String, dynamic>? extra;

  /// Header encoded as JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['type'] = type;
    json['depth'] = depth;
    if (identifier != null) {
      json['identifier'] = identifier;
    }
    if (children.isNotEmpty) {
      json['children'] =
          children.map((e) => e.toJson()).toList(growable: false);
    }
    if (width != null) {
      json['width'] = width;
    }
    if (height != null) {
      json['height'] = height;
    }
    if (x != null) {
      json['x'] = x;
    }
    if (y != null) {
      json['y'] = y;
    }
    if (z != null) {
      json['z'] = z;
    }
    if (visible != null) {
      json['visible'] = visible;
    }
    if (alpha != null) {
      json['alpha'] = alpha;
    }
    final tempExtra = extra;
    if (tempExtra != null) {
      for (final key in tempExtra.keys) {
        json[key] = tempExtra[key];
      }
    }

    return json;
  }
}
