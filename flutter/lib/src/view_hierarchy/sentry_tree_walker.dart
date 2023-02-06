import 'package:flutter/widgets.dart';

import '../../sentry_flutter.dart';
import '../widget_utils.dart';

// adapted from https://github.com/ueman/sentry-dart-tools/blob/8e41418c0f2c62dc88292cf32a4f22e79112b744/sentry_flutter_plus/lib/src/integrations/tree_walker_integration.dart

class _TreeWalker {
  static const _privateDelimiter = '_';

  _TreeWalker(this.rootElement);

  final Element rootElement;

  ValueChanged<Element> _visitor(
      SentryViewHierarchyElement parentSentryElement) {
    return (Element element) {
      final sentryElement = _toSentryViewHierarchyElement(element);

      var privateElement = false;
      // when obfuscation is enabled, this won't work because all the types
      // are renamed
      if (sentryElement.type.startsWith(_privateDelimiter) ||
          (sentryElement.identifier?.startsWith(_privateDelimiter) ?? false)) {
        privateElement = true;
      } else {
        parentSentryElement.children.add(sentryElement);
      }

      // we don't want to add private children but we still want to walk the tree
      element.visitChildElements(
          _visitor(privateElement ? parentSentryElement : sentryElement));
    };
  }

  SentryViewHierarchy? toSentryViewHierarchy() {
    final sentryRootElement = _toSentryViewHierarchyElement(rootElement);
    rootElement.visitChildElements(_visitor(sentryRootElement));

    final sentryViewHierarchy = SentryViewHierarchy('flutter');
    sentryViewHierarchy.windows.add(sentryRootElement);
    return sentryViewHierarchy;
  }

  SentryViewHierarchyElement _toSentryViewHierarchyElement(Element element) {
    final widget = element.widget;

    double? width;
    double? height;
    double? x;
    double? y;
    bool? visible;
    double? alpha;

    final renderObject = element.renderObject;
    if (renderObject is RenderBox) {
      final offset = renderObject.globalToLocal(Offset.zero);
      x = offset.dx;
      y = offset.dy;
      // no z axes in 2d

      final size = element.size;
      if (size != null) {
        width = size.width;
        height = size.height;
      }
    }

    if (widget is Visibility) {
      visible = widget.visible;
    }
    if (widget is Opacity) {
      alpha = widget.opacity;
    }

    return SentryViewHierarchyElement(
      element.widget.runtimeType.toString(),
      depth: element.depth,
      identifier: element.widget.key?.toStringValue(),
      width: width,
      height: height,
      x: x,
      y: y,
      visible: visible,
      alpha: alpha,
    );
  }
}

SentryViewHierarchy? walkWidgetTree(WidgetsBinding instance) {
  final rootElement = instance.renderViewElement;
  if (rootElement == null) {
    return null;
  }

  final walker = _TreeWalker(rootElement);

  return walker.toSentryViewHierarchy();
}
