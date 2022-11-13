import 'dart:async';

import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import '../widgets_binding_observer.dart';

/// Integration that captures certain window and device events.
/// See also:
///   - [SentryWidgetsBindingObserver]
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class WidgetsBindingIntegration extends Integration<SentryFlutterOptions> {
  late SentryWidgetsBindingObserver _observer;
  late SentryFlutterOptions _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    _observer = SentryWidgetsBindingObserver(
      hub: hub,
      options: options,
    );

    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `WidgetsFlutterBindingIntegration` already calls it.
    // If the instance is not created, we skip it to keep going.
    final instance = _options.bindingUtils.getWidgetsBindingInstance();

    instance.addObserver(_observer);
    options.sdk.addIntegration('widgetsBindingIntegration');
  }

  @override
  FutureOr<void> close() {
    final instance = _options.bindingUtils.getWidgetsBindingInstance();
    instance.removeObserver(_observer);
  }
}
