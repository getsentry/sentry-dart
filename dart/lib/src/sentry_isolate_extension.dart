import 'dart:isolate';

import 'package:meta/meta.dart';

import 'sentry_isolate.dart';
import 'hub.dart';
import 'hub_adapter.dart';

/// Record isolate errors with the Sentry SDK.
extension SentryIsolateExtension on Isolate {
  /// Calls [addErrorListener] with an error listener from the Sentry SDK. Store
  /// the returned [RawReceivePort] if you want to remove the Sentry listener
  /// again.
  ///
  /// Since isolates run concurrently, it's possible for it to exit before the
  /// error listener is established. To avoid this, start the isolate paused,
  /// add the listener and then resume the isolate.
  RawReceivePort addSentryErrorListener({@internal Hub? hub}) {
    final port = SentryIsolate.createPort(hub ?? HubAdapter());
    addErrorListener(port.sendPort);
    return port;
  }

  /// Pass the [receivePort] returned from [addSentryErrorListener] to remove
  /// the sentry error listener.
  void removeSentryErrorListener(RawReceivePort receivePort) {
    removeErrorListener(receivePort.sendPort);
  }
}
