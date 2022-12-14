import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../widget_utils.dart';
import 'user_interaction_widget.dart';

// Adapted from https://github.com/ueman/sentry-dart-tools/blob/8e41418c0f2c62dc88292cf32a4f22e79112b744/sentry_flutter_plus/lib/src/widgets/click_tracker.dart

const _tapDeltaArea = 20 * 20;
Element? _clickTrackerElement;

/// Enables the Auto instrumentation for user interaction tracing.
/// It starts a transaction and finishes after the timeout.
/// It adds a breadcrumb as well.
///
/// It's supported by the most common [Widget], for example:
/// [ButtonStyleButton], [MaterialButton], [CupertinoButton], [InkWell],
/// and [IconButton].
/// Mostly for onPressed, onTap, and onLongPress events
///
/// Example on how to set up:
/// runApp(SentryUserInteractionWidget(child: App()));
///
/// For transactions, enable it in the [SentryFlutterOptions.enableUserInteractionTracing].
/// The idle timeout can be configured in the [SentryOptions.idleTimeout].
///
/// For breadcrumbs, disable it in the [SentryFlutterOptions.enableUserInteractionBreadcrumbs].
///
/// If you are using the [SentryScreenshotWidget] as well, make sure to add
/// [SentryUserInteractionWidget] as a child of [SentryScreenshotWidget].
@experimental
class SentryUserInteractionWidget extends StatefulWidget {
  SentryUserInteractionWidget({
    Key? key,
    required this.child,
    @internal Hub? hub,
  }) : super(key: key) {
    _hub = hub ?? HubAdapter();

    if (_options?.enableUserInteractionTracing ?? false) {
      _options?.sdk.addIntegration('UserInteractionTracing');
    }
  }

  final Widget child;

  late final Hub _hub;

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      _hub.options as SentryFlutterOptions?;

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
  UserInteractionWidget? _lastTappedWidget;
  ISentrySpan? _activeTransaction;

  Hub get _hub => widget._hub;

  SentryFlutterOptions? get _options => widget._options;

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
    final keyValue = tappedWidget?.element.widget.key?.toStringValue();
    if (tappedWidget == null || keyValue == null) {
      return;
    }
    final element = tappedWidget.element;

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
        viewId: keyValue,
        viewClass: tappedWidget.type, // to avoid minification
        data: data,
      );
      final hint = Hint.withMap({TypeCheckHint.widget: element.widget});
      _hub.addBreadcrumb(crumb, hint: hint);
    }

    // ignore: invalid_use_of_internal_member
    if (!(_options?.isTracingEnabled() ?? false) ||
        !(_options?.enableUserInteractionTracing ?? false)) {
      return;
    }

    // getting the name of the screen using ModalRoute.of(context).settings.name
    // is expensive, so we expect that the keys are unique across the app
    final transactionContext = SentryTransactionContext(
      keyValue,
      'ui.action.$category',
      transactionNameSource: SentryTransactionNameSource.component,
    );

    final activeTransaction = _activeTransaction;
    if (activeTransaction != null) {
      if (_lastTappedWidget?.element.widget == element.widget &&
          _lastTappedWidget?.eventType == tappedWidget.eventType &&
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
        _lastTappedWidget = null;
      }
    }

    _lastTappedWidget = tappedWidget;

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

  UserInteractionWidget? _getElementAt(Offset position) {
    // WidgetsBinding.instance.renderViewElement does not work, so using
    // the element from createElement
    final rootElement = _clickTrackerElement;
    if (rootElement == null || rootElement.widget != widget) {
      return null;
    }

    UserInteractionWidget? tappedWidget;

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

  UserInteractionWidget? _getDescriptionFrom(Element element) {
    final widget = element.widget;
    // Used by ElevatedButton, TextButton, OutlinedButton.
    if (widget is ButtonStyleButton) {
      if (widget.enabled) {
        return UserInteractionWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'ButtonStyleButton',
          eventType: 'onClick',
        );
      }
    } else if (widget is MaterialButton) {
      if (widget.enabled) {
        return UserInteractionWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'MaterialButton',
          eventType: 'onClick',
        );
      }
    } else if (widget is CupertinoButton) {
      if (widget.enabled) {
        return UserInteractionWidget(
          element: element,
          description: _findDescriptionOf(element, true),
          type: 'CupertinoButton',
          eventType: 'onPressed',
        );
      }
    } else if (widget is InkWell) {
      if (widget.onTap != null) {
        return UserInteractionWidget(
          element: element,
          description: _findDescriptionOf(element, false),
          type: 'InkWell',
          eventType: 'onTap',
        );
      }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) {
        return UserInteractionWidget(
          element: element,
          description: _findDescriptionOf(element, false),
          type: 'IconButton',
          eventType: 'onPressed',
        );
      }
    }

    return null;
  }
}
