import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// It is necessary to initialize Flutter method channels so that our plugin can
/// call into the native code.
class WidgetsFlutterBindingIntegration
    extends Integration<SentryFlutterOptions> {
  WidgetsFlutterBindingIntegration(
      [WidgetsBinding Function()? ensureInitialized])
      : _ensureInitialized =
            ensureInitialized ?? WidgetsFlutterBinding.ensureInitialized;

  final WidgetsBinding Function() _ensureInitialized;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _ensureInitialized();
    options.sdk.addIntegration('widgetsFlutterBindingIntegration');
  }
}
