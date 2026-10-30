import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../utils/internal_logger.dart';

@internal
final class UserInteractionWidgetTypes {
  final _names = <String? Function(Widget widget)>[];

  void addWidget<T extends Widget>(
    String name, {
    bool Function(T widget)? isEnabled,
  }) {
    _names.add(
      (widget) =>
          widget is T && (isEnabled?.call(widget) ?? true) ? name : null,
    );
  }

  String? nameOf(Widget widget) {
    for (final lookup in _names) {
      try {
        final name = lookup(widget);
        if (name != null) {
          return name;
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'User interaction callback failed for ${widget.runtimeType}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }
}
