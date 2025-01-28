import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

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

  const SentryScreenshotWidget({super.key, required this.child});

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
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final status = SentryScreenshotWidgetStatus(
      size: mq.size,
      pixelRatio: mq.devicePixelRatio,
      orientantion: mq.orientation,
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

    return RepaintBoundary(
      key: sentryScreenshotWidgetGlobalKey,
      child: widget.child,
    );
  }
}

@visibleForTesting
@immutable
class SentryScreenshotWidgetStatus {
  final Size? size;
  final double? pixelRatio;
  final Orientation? orientantion;

  const SentryScreenshotWidgetStatus({
    required this.size,
    required this.pixelRatio,
    required this.orientantion,
  });
}
