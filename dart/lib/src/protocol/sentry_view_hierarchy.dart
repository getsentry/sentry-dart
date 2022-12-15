import 'package:meta/meta.dart';

import 'sentry_view_hierarchy_element.dart';

@immutable
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
