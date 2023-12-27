import 'noop_connectivity_provider.dart'
    if (dart.library.html) 'web_connectivity_provider.dart';

abstract class ConnectivityProvider {
  factory ConnectivityProvider() => connectivityProvider();

  void listen(void Function(String connectivity) onChange);
  void cancel();
}
