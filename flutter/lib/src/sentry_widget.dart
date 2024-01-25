import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// This widget serves as a wrapper to conditionally include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  late final Hub _hub;
  final Widget child;

  SentryWidget({super.key, required this.child, @internal Hub? hub})
      : _hub = hub ?? HubAdapter();

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  final _options = SentryFlutter.flutterOptions;

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    content = _wrapWithScreenshotIfNeeded(content);
    content = _wrapWithUserInteractionIfNeeded(content);
    return content;
  }

  Widget _wrapWithScreenshotIfNeeded(Widget child) {
    if (_options.attachScreenshot) {
      return SentryScreenshotWidget(child: child);
    }
    return child;
  }

  Widget _wrapWithUserInteractionIfNeeded(Widget child) {
    if (_options.enableUserInteractionTracing ||
        _options.enableUserInteractionBreadcrumbs) {
      return SentryUserInteractionWidget(hub: widget._hub, child: child);
    }
    return child;
  }
}
