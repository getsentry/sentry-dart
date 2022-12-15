import 'package:meta/meta.dart';

import 'sentry_view_hierarchy_element.dart';

@immutable
class SentryViewHierarchy {
  SentryViewHierarchy(this.renderingSystem);

  final String renderingSystem;
  final List<SentryViewHierarchyElement> windows = [];

  /// Header encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'rendering_system': renderingSystem,
      if (windows.isNotEmpty)
        'windows': windows.map((e) => e.toJson()).toList(growable: false),
    };
  }
}
