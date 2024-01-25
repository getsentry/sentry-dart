import 'package:flutter/cupertino.dart';
import '../sentry_flutter.dart';

/// A central widget that contains the Sentry widgets.
class SentryWidget extends StatefulWidget {
  const SentryWidget({super.key, required this.child});

  final Widget child;

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  final _options = SentryFlutter.flutterOptions;

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    content = _maybeWrapScreenshotWidget(content);
    content = _maybeWrapUserInteractionWidget(content);
    return content;
  }

  Widget _maybeWrapScreenshotWidget(Widget child) {
    if (_options.attachScreenshot) {
      return SentryScreenshotWidget(child: child);
    }
    return child;
  }

  Widget _maybeWrapUserInteractionWidget(Widget child) {
    if (_options.enableUserInteractionTracing ||
        _options.enableUserInteractionBreadcrumbs) {
      return SentryUserInteractionWidget(child: child);
    }
    return child;
  }
}
