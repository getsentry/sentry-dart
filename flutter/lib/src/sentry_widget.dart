import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// Key which is used to identify the [SentryWidget]
@internal
final sentryWidgetGlobalKey = GlobalKey(debugLabel: 'sentry_widget');

/// This widget serves as a wrapper to include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  final Widget child;
  late final Hub _hub;

  SentryWidget({
    super.key,
    required this.child,
    @internal Hub? hub,
  }) {
    _hub = hub ?? HubAdapter();
  }

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      _hub.options is SentryFlutterOptions
          // ignore: invalid_use_of_internal_member
          ? _hub.options as SentryFlutterOptions?
          : null;

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget._options?.isMultiViewApp ?? false) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.logger(
        SentryLevel.debug,
        '`SentryWidget` is not available in multi-view apps.',
      );
      return content;
    } else {
      content = SentryScreenshotWidget(child: content);
      content = SentryUserInteractionWidget(child: content);
      return Container(
        key: sentryWidgetGlobalKey,
        child: content,
      );
    }
  }
}
