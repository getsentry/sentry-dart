import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'widget_click/tapped_widget.dart';

// Adapted from https://github.com/ueman/sentry-dart-tools/blob/8e41418c0f2c62dc88292cf32a4f22e79112b744/sentry_flutter_plus/lib/src/widgets/click_tracker.dart

const _tapDeltaArea = 20 * 20;
Element? _clickTrackerElement;

class SentryUserInteractionWidget extends StatefulWidget {
  SentryUserInteractionWidget({
    Key? key,
    required this.child,
    @internal Hub? hub,
  }) : super(key: key) {
    _hub = hub ?? HubAdapter();
  }

  final Widget child;

  late final Hub _hub;

  @override
  StatefulElement createElement() {
    final element = super.createElement();
    _clickTrackerElement = element;
    return element;
  }

  @override
  _SentryUserInteractionWidgetState createState() =>
      _SentryUserInteractionWidgetState();
}

class _SentryUserInteractionWidgetState
    extends State<SentryUserInteractionWidget> {
  int? _lastPointerId;
  Offset? _lastPointerDownLocation;
  Widget? _lastWidget;
  ISentrySpan? _activeTransaction;

  Hub get _hub => widget._hub;

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      _hub.options as SentryFlutterOptions?;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerId = event.pointer;
    _lastPointerDownLocation = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    // Figure out if something was tapped
    final location = _lastPointerDownLocation;
    if (location == null || event.pointer != _lastPointerId) {
      return;
    }
    final delta = Offset(
      location.dx - event.localPosition.dx,
      location.dy - event.localPosition.dy,
    );

    if (delta.distanceSquared < _tapDeltaArea) {
      // Widget was tapped
      _onTappedAt(event.localPosition);
    }
  }

  void _onTappedAt(Offset position) {
    final tappedWidget = _getElementAt(position);
    if (tappedWidget == null || tappedWidget.keyValue == null) {
      return;
    }

    Map<String, dynamic>? data;
    // ignore: invalid_use_of_internal_member
    if ((_options?.sendDefaultPii ?? false) &&
        tappedWidget.description.isNotEmpty) {
      data = {};
      data['label'] = tappedWidget.description;
    }

    const category = 'click';
    // ignore: invalid_use_of_internal_member
    if (_options?.enableUserInteractionBreadcrumbs ?? false) {
      final crumb = Breadcrumb.userInteraction(
        subCategory: category,
        viewId: tappedWidget.keyValue,
        // viewClass: tappedWidget.element.widget.runtimeType.toString(),
        viewClass: tappedWidget.type, // to avoid minification
        data: data,
      );
      _hub.addBreadcrumb(crumb, hint: tappedWidget.element.widget);
    }

    // ignore: invalid_use_of_internal_member
    if (!(_options?.isTracingEnabled() ?? false) ||
        !(_options?.enableUserInteractionTracing ?? false)) {
      return;
    }

    // TODO: name should be screenName.widgetName, maybe get from router?
    final transactionContext = SentryTransactionContext(
      tappedWidget.keyValue!,
      'ui.action.$category',
      transactionNameSource: SentryTransactionNameSource.component,
    );

    // TODO: check if when starting a new child, the timer is reset
    // TODO: check the type of the event in the widget
    final activeTransaction = _activeTransaction;
    if (activeTransaction != null) {
      if (_lastWidget == tappedWidget.element.widget &&
          !activeTransaction.finished) {
        // ignore: invalid_use_of_internal_member
        activeTransaction.scheduleFinish();
        return;
      } else {
        activeTransaction.finish();
        _hub.configureScope((scope) {
          if (scope.span == activeTransaction) {
            scope.span = null;
          }
        });
        _activeTransaction = null;
        _lastWidget = null;
      }
    }

    _lastWidget = tappedWidget.element.widget;

    bool hasRunningTransaction = false;
    _hub.configureScope((scope) {
      if (scope.span != null) {
        hasRunningTransaction = true;
      }
    });

    if (hasRunningTransaction) {
      return;
    }

    // TODO: mobile vitals
    _activeTransaction = _hub.startTransactionWithContext(
      transactionContext,
      waitForChildren: true,
      autoFinishAfter:
          // ignore: invalid_use_of_internal_member
          _options?.idleTimeout,
      trimEnd: true,
    );

    // if _enableAutoTransactions is enabled but there's no traces sample rate
    if (_activeTransaction is NoOpSentrySpan) {
      return;
    }

    _hub.configureScope((scope) {
      scope.span ??= _activeTransaction;
    });
  }

  String _findDescriptionOf(Element element, bool allowText) {
    var description = '';

    // traverse tree to find a suiting element
    void descriptionFinder(Element element) {
      bool foundDescription = false;

      final widget = element.widget;
      if (allowText && widget is Text) {
        final data = widget.data;
        if (data != null && data.isNotEmpty) {
          description = data;
          foundDescription = true;
        }
      } else if (widget is Semantics) {
        if (widget.properties.label?.isNotEmpty ?? false) {
          description = widget.properties.label!;
          foundDescription = true;
        }
      } else if (widget is Icon) {
        if (widget.semanticLabel?.isNotEmpty ?? false) {
          description = widget.semanticLabel!;
          foundDescription = true;
        }
      }

      if (!foundDescription) {
        element.visitChildren(descriptionFinder);
      }
    }

    element.visitChildren(descriptionFinder);

    return description;
  }

  TappedWidget? _getElementAt(Offset position) {
    // WidgetsBinding.instance.renderViewElement does not work, so using
    // the element from createElement
    final rootElement = _clickTrackerElement;
    if (rootElement == null || rootElement.widget != widget) {
      return null;
    }

    TappedWidget? tappedWidget;

    void elementFinder(Element element) {
      if (tappedWidget != null) {
        // element was found
        return;
      }

      final renderObject = element.renderObject;
      if (renderObject == null) {
        return;
      }

      final transform = renderObject.getTransformTo(rootElement.renderObject);
      final paintBounds =
          MatrixUtils.transformRect(transform, renderObject.paintBounds);

      if (!paintBounds.contains(position)) {
        return;
      }
      tappedWidget = _getDescriptionFrom(element);

      if (tappedWidget == null) {
        element.visitChildElements(elementFinder);
      }
    }

    rootElement.visitChildElements(elementFinder);

    return tappedWidget;
  }

  TappedWidget? _getDescriptionFrom(Element element) {
    final widget = element.widget;
    // Used by ElevatedButton, TextButton, OutlinedButton.
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        return TappedWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'ButtonStyleButton',
        );
      }
    } else if (widget is MaterialButton) {
      if (widget.enabled) {
        return TappedWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'MaterialButton',
        );
      }
    } else if (widget is CupertinoButton) {
      if (widget.enabled) {
        return TappedWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'CupertinoButton',
        );
      }
    } else if (widget is InkWell) {
      if (widget.onTap != null) {
        return TappedWidget(
          element: element,
          description: _findDescriptionOf(element, false),
          type: 'InkWell',
        );
      }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) {
        return TappedWidget(
          element: element,
          description: _findDescriptionOf(element, false),
          type: 'IconButton',
        );
      }
    } else if (widget is GestureDetector) {
      if (widget.onTap != null) {
        return TappedWidget(
          element: element,
          description: '',
          type: 'GestureDetector',
        );
      }
    }

    return null;
  }
}
