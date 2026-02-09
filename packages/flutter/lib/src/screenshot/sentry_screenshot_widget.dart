import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

/// Key which is used to identify the [RepaintBoundary]
@internal
final sentryScreenshotWidgetGlobalKey =
    GlobalKey(debugLabel: 'sentry_screenshot_widget');

/// You can add screenshots of [child] to crash reports by adding this widget.
/// Ideally you are adding it around your app widget like in the following
/// example.
/// ```dart
/// runApp(SentryScreenshotWidget(child: App()));
/// ```
///
/// Remarks:
/// - Depending on the place where it's used, you might have a transparent
///   background.
/// - Platform Views currently can't be captured.
/// - Works with skia renderer & canvas kit renderer if running on web. For more
///   information see https://flutter.dev/docs/development/tools/web-renderers
/// - You can only have one [SentryScreenshotWidget] widget in your widget tree at all
///   times.
class SentryScreenshotWidget extends StatefulWidget {
  final Widget child;
  final Hub _hub;

  SentryScreenshotWidget({
    required this.child,
    @internal Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        super(key: sentryScreenshotWidgetGlobalKey);

  @internal
  static void showTakeScreenshotButton() {
    final state = sentryScreenshotWidgetGlobalKey.currentState
        as _SentryScreenshotWidgetState?;
    state?._toggleScreenshotButton(true);
  }

  @internal
  static void hideTakeScreenshotButton() {
    final state = sentryScreenshotWidgetGlobalKey.currentState
        as _SentryScreenshotWidgetState?;
    state?._toggleScreenshotButton(false);
  }

  @override
  _SentryScreenshotWidgetState createState() => _SentryScreenshotWidgetState();

  /// This is true when the [SentryScreenshotWidget] is in the widget tree.
  @internal
  static bool get isMounted =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @internal
  static void reset() {
    _status = null;
    _onBuild.clear();
  }

  static SentryScreenshotWidgetStatus? _status;
  static final _onBuild = <SentryScreenshotWidgetOnBuildCallback>[];

  /// Registers a persistent callback that is called whenever the widget is
  /// built. The callback is called with the current and previous widget status.
  /// To unregister, return false;
  /// If the widget is already built, the callback is called immediately.
  /// Note: the callback must not throw and it must not call onBuild().
  @internal
  static void onBuild(SentryScreenshotWidgetOnBuildCallback callback) {
    bool register = true;
    final currentStatus = _status;
    if (currentStatus != null) {
      register = callback(currentStatus, null);
    }
    if (register) {
      _onBuild.add(callback);
    }
  }
}

typedef SentryScreenshotWidgetOnBuildCallback = bool Function(
    SentryScreenshotWidgetStatus currentStatus,
    SentryScreenshotWidgetStatus? previousStatus);

class _SentryScreenshotWidgetState extends State<SentryScreenshotWidget> {
  bool _isScreenshotButtonVisible = false;

  void _toggleScreenshotButton(bool show) {
    setState(() {
      _isScreenshotButtonVisible = show;
    });
  }

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      widget._hub.options is SentryFlutterOptions
          // ignore: invalid_use_of_internal_member
          ? widget._hub.options as SentryFlutterOptions?
          : null;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final status = SentryScreenshotWidgetStatus(
      size: mq.size,
      pixelRatio: mq.devicePixelRatio,
      orientation: mq.orientation,
    );
    final prevStatus = SentryScreenshotWidget._status;
    SentryScreenshotWidget._status = status;

    if (SentryScreenshotWidget._onBuild.isNotEmpty) {
      final unregisterCallbacks = <SentryScreenshotWidgetOnBuildCallback>[];
      for (final callback in SentryScreenshotWidget._onBuild) {
        if (!callback(status, prevStatus)) {
          unregisterCallbacks.add(callback);
        }
      }
      unregisterCallbacks.forEach(SentryScreenshotWidget._onBuild.remove);
    }

    if (_isScreenshotButtonVisible) {
      // Detect the current text direction or fall back to LTR
      final textDirection =
          Directionality.maybeOf(context) ?? TextDirection.ltr;

      return RepaintBoundary(
        child: Directionality(
          textDirection: textDirection,
          child: Stack(
            children: [
              widget.child,
              PositionedDirectional(
                end: 32,
                bottom: 32,
                child: ElevatedButton.icon(
                  key: const ValueKey(
                      'sentry_screenshot_take_screenshot_button'),
                  onPressed: () async {
                    SentryScreenshotWidget.hideTakeScreenshotButton();
                    final screenshot = await SentryFlutter.captureScreenshot();

                    final currentContext =
                        _options?.navigatorKey?.currentContext;

                    if (currentContext != null && currentContext.mounted) {
                      SentryFeedbackWidget.show(
                        currentContext,
                        associatedEventId:
                            SentryFeedbackWidget.pendingAssociatedEventId,
                        screenshot: screenshot,
                        hub: widget._hub,
                      );
                    }
                  },
                  icon: Icon(
                    Icons.screenshot_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24.0,
                  ),
                  label: Text(
                    _options?.feedback.takeScreenshotButtonLabel ??
                        'Take Screenshot',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: widget.child,
    );
  }
}

@visibleForTesting
@immutable
class SentryScreenshotWidgetStatus {
  final Size? size;
  final double? pixelRatio;
  final Orientation? orientation;

  static const double _pixelRatioTolerance = 1e-6;
  static const double _sizeTolerance = 0.05;

  const SentryScreenshotWidgetStatus({
    required this.size,
    required this.pixelRatio,
    required this.orientation,
  });

  bool matches(SentryScreenshotWidgetStatus other) {
    if (identical(this, other)) return true;
    if (orientation != other.orientation) return false;

    if (pixelRatio == null || other.pixelRatio == null) {
      if (pixelRatio != other.pixelRatio) return false;
    } else if ((pixelRatio! - other.pixelRatio!).abs() > _pixelRatioTolerance) {
      return false;
    }

    if (size == null || other.size == null) {
      if (size != other.size) return false;
    } else {
      if ((size!.width - other.size!.width).abs() > _sizeTolerance) {
        return false;
      }
      if ((size!.height - other.size!.height).abs() > _sizeTolerance) {
        return false;
      }
    }

    return true;
  }
}
