import 'dart:async';
import 'dart:isolate';

import 'hub.dart';
import 'integration.dart';
import 'sentry_isolate_extension.dart';
import 'sentry_options.dart';

class IsolateErrorIntegration extends Integration {
  RawReceivePort? _receivePort;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _receivePort = Isolate.current.addSentryErrorListener();
    options.sdk.addIntegration('isolateErrorIntegration');
  }

  @override
  void close() {
    final receivePort = _receivePort;
    if (receivePort != null) {
      receivePort.close();
      Isolate.current.removeSentryErrorListener(receivePort);
    }
  }
}
