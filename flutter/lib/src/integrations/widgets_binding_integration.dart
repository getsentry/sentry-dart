import 'dart:async';

import 'package:sentry/sentry.dart';
import '../binding_utils.dart';
import '../sentry_flutter_options.dart';
import '../widgets_binding_observer.dart';

/// Integration that captures certain window and device events.
/// See also:
///   - [SentryWidgetsBindingObserver]
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class WidgetsBindingIntegration extends Integration<SentryFlutterOptions> {
  SentryWidgetsBindingObserver? _observer;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _observer = SentryWidgetsBindingObserver(
      hub: hub,
      options: options,
    );

    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `WidgetsFlutterBindingIntegration` already calls it.
    // If the instance is not created, we skip it to keep going.
    final instance = BindingUtils.getWidgetsBindingInstance();
    if (instance != null) {
      instance.addObserver(_observer!);
      options.sdk.addIntegration('widgetsBindingIntegration');
    } else {
      options.logger(
        SentryLevel.error,
        'widgetsBindingIntegration failed to be installed',
      );
    }
  }

  @override
  FutureOr<void> close() {
    final instance = BindingUtils.getWidgetsBindingInstance();
    if (instance != null && _observer != null) {
      instance.removeObserver(_observer!);
    }
  }
}
