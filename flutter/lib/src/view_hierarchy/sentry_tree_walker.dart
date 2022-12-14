import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../sentry_flutter.dart';
import 'sentry_view_hierarchy.dart';
import '../widget_utils.dart';

class _TreeWalker {
  final Element rootElement;

  _TreeWalker(this.rootElement);

  ValueChanged<Element> _visitor(SentryViewHierarchyElement parentNode) {
    return (Element element) {
      final node = _toSentryViewHierarchyElement(element);
      parentNode.children.add(node);
      element.visitChildElements(_visitor(node));
    };
  }

  SentryViewHierarchy? toSentryViewHierarchy() {
    final rootNode = _toSentryViewHierarchyElement(rootElement);
    rootElement.visitChildElements(_visitor(rootNode));

    final sentryViewHierarchy = SentryViewHierarchy('flutter');
    sentryViewHierarchy.windows.add(rootNode);
    return sentryViewHierarchy;
  }

  SentryViewHierarchyElement _toSentryViewHierarchyElement(Element element) {
    final node = SentryViewHierarchyElement(
      element.widget.runtimeType.toString(),
      element.depth,
      identifier: element.widget.key?.toStringValue(),
    );

    final widget = element.widget;
    if (widget is RenderBox) {
      final size = element.size;
      node.width = size?.width;
      node.height = size?.height;
    }
    if (widget is Visibility) {
      node.visible = widget.visible;
    }
    // TODO: not sure how to get Color#alpha direcly?
    if (widget is Opacity) {
      node.alpha = widget.opacity;
    }
    // TODO: missing x, y, z, and extra if any?

    return node;
  }
}

Uint8List? widgetTree(WidgetsBinding instance) {
  final rootElement = instance.renderViewElement;
  if (rootElement == null) {
    return null;
  }
  final walker = _TreeWalker(rootElement);

  final sentryViewHierarchy = walker.toSentryViewHierarchy();
  if (sentryViewHierarchy == null) {
    return null;
  }

  // TODO: this can be done async similar to SentryEvent
  final bytes = utf8JsonEncoder.convert(sentryViewHierarchy.toJson());
  if (bytes.isEmpty) {
    return null;
  }
  return Uint8List.fromList(bytes);
}
