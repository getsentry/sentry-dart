import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

typedef OnWidgetsBinding = WidgetsBinding Function();

/// It is necessary to initialize Flutter method channels so that our plugin can
/// call into the native code.
class WidgetsFlutterBindingIntegration
    extends Integration<SentryFlutterOptions> {
  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.bindingUtils.ensureInitialized();
    options.sdk.addIntegration('widgetsFlutterBindingIntegration');
  }
}
