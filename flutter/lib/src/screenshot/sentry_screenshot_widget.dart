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
  late final Hub _hub;

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      _hub.options is SentryFlutterOptions
          // ignore: invalid_use_of_internal_member
          ? _hub.options as SentryFlutterOptions
          : null;

  SentryScreenshotWidget({
    super.key,
    required this.child,
    @internal Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  @override
  _SentryScreenshotWidgetState createState() => _SentryScreenshotWidgetState();
}

class _SentryScreenshotWidgetState extends State<SentryScreenshotWidget> {
  SentryFlutterOptions? get _options => widget._options;

  @override
  Widget build(BuildContext context) {
    if (_options?.attachScreenshot ?? false) {
      return RepaintBoundary(
        key: sentryScreenshotWidgetGlobalKey,
        child: widget.child,
      );
    }
    return widget.child;
  }
}
