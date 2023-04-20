import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import '../widgets_binding_observer.dart';

/// Integration that captures certain window and device events.
/// See also:
///   - [SentryWidgetsBindingObserver]
///   - [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html)
class WidgetsBindingIntegration implements Integration<SentryFlutterOptions> {
  SentryWidgetsBindingObserver? _observer;
  SentryFlutterOptions? _options;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    final observer = SentryWidgetsBindingObserver(
      hub: hub,
      options: options,
    );
    _observer = observer;

    // We don't need to call `WidgetsFlutterBinding.ensureInitialized()`
    // because `WidgetsFlutterBindingIntegration` already calls it.
    // If the instance is not created, we skip it to keep going.
    final instance = options.bindingUtils.instance;
    if (instance != null) {
      instance.addObserver(observer);
      options.sdk.addIntegration('widgetsBindingIntegration');
    }
  }

  @override
  void close() {
    final instance = _options?.bindingUtils.instance;
    final observer = _observer;
    if (instance != null && observer != null) {
      instance.removeObserver(observer);
    }
  }
}
