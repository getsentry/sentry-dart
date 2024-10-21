import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';
import 'utils/multi_view/multi_view_helper.dart';

/// Key which is used to identify the [SentryWidget]
@internal
final sentryWidgetGlobalKey = GlobalKey(debugLabel: 'sentry_widget');

/// This widget serves as a wrapper to include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  final Widget child;

  SentryWidget({
    super.key,
    required this.child,
    @internal Hub? hub,
  });

  final bool _isMultiViewEnabled = MultiViewHelper().isMultiViewEnabled();

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget._isMultiViewEnabled) {
      return content;
    }
    content = SentryScreenshotWidget(child: content);
    content = SentryUserInteractionWidget(child: content);
    return Container(
      key: sentryWidgetGlobalKey,
      child: content,
    );
  }
}
