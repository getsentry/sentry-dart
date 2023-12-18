import 'package:meta/meta.dart';
import '../../../sentry_flutter.dart';
import 'connectivity_provider.dart';

class ConnectivityIntegration extends Integration<SentryFlutterOptions> {
  Hub? _hub;
  ConnectivityProvider? _connectivityProvider;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _hub = hub;
    _connectivityProvider = ConnectivityProvider();
    _connectivityProvider?.listen((connectivity) {
      addBreadcrumb(connectivity);
    });
    options.sdk.addIntegration('connectivityIntegration');
  }

  @override
  void close() {
    _hub = null;
    _connectivityProvider?.cancel();
  }

  @internal
  @visibleForTesting
  void addBreadcrumb(String connectivity) {
    _hub?.addBreadcrumb(
      Breadcrumb(
          category: 'device.connectivity',
          level: SentryLevel.info,
          type: 'connectivity',
          data: {'connectivity': connectivity}),
    );
  }
}
