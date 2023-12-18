import 'connectivity_provider.dart';

ConnectivityProvider connectivityProvider() {
  return NoOpConnectivityProvider();
}

class NoOpConnectivityProvider implements ConnectivityProvider {
  @override
  void listen(void Function(String connectivity) onChange) {
    // NoOp
  }

  @override
  void cancel() {
    // NoOp
  }
}
