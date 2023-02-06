import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry_isolate.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

class IsolateErrorIntegration extends Integration {
  RawReceivePort? _receivePort;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _receivePort = Isolate.current.addSentryErrorListener();
    options.sdk.addIntegration('isolateErrorIntegration');
  }

  @override
  void close() {
    final safeReceivePort = _receivePort;
    if (safeReceivePort != null) {
      Isolate.current.removeSentryErrorListener(safeReceivePort);
    }
  }
}
