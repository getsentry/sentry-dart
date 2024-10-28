import 'package:meta/meta.dart';

import 'package:flutter/widgets.dart' as widgets;

/// Key which is used to identify the [RepaintBoundary]
@internal
final sentryScreenshotWidgetGlobalKey =
    widgets.GlobalKey(debugLabel: 'sentry_screenshot_widget');

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
class SentryScreenshotWidget extends widgets.StatefulWidget {
  final widgets.Widget child;

  const SentryScreenshotWidget({super.key, required this.child});

  @override
  _SentryScreenshotWidgetState createState() => _SentryScreenshotWidgetState();

  /// This is true when the [SentryScreenshotWidget] is in the widget tree.
  static bool get isMounted =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;
}

class _SentryScreenshotWidgetState
    extends widgets.State<SentryScreenshotWidget> {
  @override
  widgets.Widget build(widgets.BuildContext context) {
    return widgets.RepaintBoundary(
      key: sentryScreenshotWidgetGlobalKey,
      child: widget.child,
    );
  }
}
