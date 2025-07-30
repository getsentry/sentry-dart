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
    final jsonMap = {
      'type': type,
      if (depth != null) 'depth': depth,
      if (identifier != null) 'identifier': identifier,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (z != null) 'z': z,
      if (visible != null) 'visible': visible,
      if (alpha != null) 'alpha': alpha,
      if (children.isNotEmpty)
        'children': children.map((e) => e.toJson()).toList(growable: false),
    };

    if (extra?.isNotEmpty ?? false) {
      jsonMap.addAll(extra!);
    }

    return jsonMap;
  }
}
