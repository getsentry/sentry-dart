// import 'package:flutter/material.dart';

// @immutable
class SentryViewHierarchy {
  SentryViewHierarchy(this.renderingSystem);

  final String renderingSystem;
  final List<SentryViewHierarchyElement> windows = [];

  /// Header encoded as JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['rendering_system'] = renderingSystem;
    if (windows.isNotEmpty) {
      json['windows'] = windows.map((e) => e.toJson()).toList(growable: false);
    }

    return json;
  }
}

// @immutable
class SentryViewHierarchyElement {
  SentryViewHierarchyElement(
    this.type,
    this.depth, {
    this.identifier,
    // this.children,
    // this.width,
    // this.height,
    // this.depth,
    // this.x,
    // this.y,
    // this.z,
    // this.visible,
    // this.alpha,
    // this.extra,
  });

  final String type;
  int depth;
  final String? identifier;
  List<SentryViewHierarchyElement> children = [];
  double? width;
  double? height;
  double? x;
  double? y;
  double? z;
  bool? visible;
  double? alpha;
  Map<String, dynamic>? extra;

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
