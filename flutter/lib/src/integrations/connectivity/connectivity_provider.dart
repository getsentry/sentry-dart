import 'noop_connectivity_provider.dart'
    if (dart.library.html) 'html_connectivity_provider.dart'
    if (dart.library.js_interop) 'web_connectivity_provider.dart';

abstract class ConnectivityProvider {
  factory ConnectivityProvider() => connectivityProvider();

  void listen(void Function(String connectivity) onChange);
  void cancel();
}
