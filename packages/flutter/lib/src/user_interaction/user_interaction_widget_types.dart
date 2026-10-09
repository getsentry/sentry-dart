import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../utils/internal_logger.dart';

@internal
typedef UserInteractionWidgetType = ({String name, bool labelFromText});

@internal
final class UserInteractionWidgetTypes {
  final _types = <UserInteractionWidgetType? Function(Widget widget)>[];
  final _labels = <String? Function(Widget widget)>[];

  void addWidget<T extends Widget>(
    String name, {
    bool Function(T widget)? isEnabled,
    bool labelFromText = false,
  }) {
    final type = (name: name, labelFromText: labelFromText);
    _types.add((widget) =>
        widget is T && (isEnabled?.call(widget) ?? true) ? type : null);
  }

  void addLabel<T extends Widget>(String? Function(T widget) labelOf) {
    _labels.add((widget) => widget is T ? labelOf(widget) : null);
  }

  UserInteractionWidgetType? typeOf(Widget widget) =>
      _firstResult(_types, widget);

  String? labelOf(Widget widget) => _firstResult(_labels, widget);

  static R? _firstResult<R extends Object>(
    List<R? Function(Widget widget)> lookups,
    Widget widget,
  ) {
    for (final lookup in lookups) {
      try {
        final result = lookup(widget);
        if (result != null) {
          return result;
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
