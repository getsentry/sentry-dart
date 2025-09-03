import 'dart:developer' as developer;
import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'isolate_diagnostic_log.dart';

// -------------------------------------------
// HOST-SIDE API (runs on the main isolate)
// -------------------------------------------

/// Uniform lifecycle for any host-facing worker facade.
abstract class WorkerHandle {
  FutureOr<void> start();
  FutureOr<void> close();
}

/// Minimal config passed to isolates. Extend as needed.
class IsolateConfig {
  final bool debug;
  final SentryLevel logLevel;
  final String? debugName;

  const IsolateConfig({
    required this.debug,
    required this.logLevel,
    this.debugName,
  });
}

/// Host-side helper for workers to perform minimal request/response.
class IsolateClient {
  IsolateClient(this._workerPort) {
    _responses.listen(_handleResponse);
  }

  final SendPort _workerPort;
  SendPort get port => _workerPort;
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<Object?>> _pending = {};
  int _idCounter = 0;
  bool _closed = false;

  /// Fire-and-forget send to the worker.
  void send(Object? message) {
    _workerPort.send(message);
  }

  /// Send a request to the worker and await a response.
  Future<Object?> request(Object? payload) {
    if (_closed) throw StateError('IsolateClient is closed');
    final id = _idCounter++;
    final completer = Completer<Object?>.sync();
    _pending[id] = completer;
    _workerPort.send((id, payload, _responses.sendPort));
    return completer.future;
  }

  void close() {
    if (_closed) return;
    _workerPort.send(_Ctl.shutdown);
    _closed = true;
    if (_pending.isEmpty) {
      _responses.close();
    }
  }

  void _handleResponse(dynamic message) {
    final (int id, Object? response) = message as (int, Object?);
    final completer = _pending.remove(id);
    if (completer == null) return;

    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response);
    }

    if (_closed && _pending.isEmpty) {
      _responses.close();
    }
  }
}

class _Ctl {
  static const shutdown = '_shutdown_';
}

/// Isolate entry-point signature.
typedef IsolateEntry = void Function((SendPort, IsolateConfig));

/// Spawn an isolate and handshake to obtain its SendPort.
Future<IsolateClient> spawnIsolate(
  IsolateConfig config,
  IsolateEntry entry,
) async {
  final receivePort = ReceivePort();
  await Isolate.spawn<(SendPort, IsolateConfig)>(
    entry,
    (receivePort.sendPort, config),
    debugName: config.debugName,
  );
  final workerPort = await receivePort.first as SendPort;
  return IsolateClient(workerPort);
}

// -------------------------------------------
// ISOLATE-SIDE API (runs inside the worker isolate)
// -------------------------------------------

/// Domain behavior contract implemented INSIDE the worker isolate.
abstract class IsolateMessageHandler {
  FutureOr<void> onMessage(Object? message);
  FutureOr<Object?> onRequest(Object? payload) => null;
}

/// Generic isolate runtime. Reuse for every Sentry worker.
void runIsolate(
  IsolateConfig config,
  SendPort host,
  IsolateMessageHandler logic,
) {
  // TODO: we might want to configure this at init overall since we shouldn't need isolate specific log setups
  IsolateDiagnosticLog.configure(
    debug: config.debug,
    level: config.logLevel,
  );

  final inbox = ReceivePort();
  host.send(inbox.sendPort);

  inbox.listen((msg) async {
    if (msg == _Ctl.shutdown) {
      IsolateDiagnosticLog.log(
          SentryLevel.debug, 'Isolate received shutdown request',
          logger: config.debugName);
      inbox.close();
      IsolateDiagnosticLog.log(SentryLevel.debug, 'Isolate closed.',
          logger: config.debugName);
      return;
    }

    // RPC: (id, payload, replyTo)
    if (msg is (int, Object?, SendPort)) {
      final (id, payload, replyTo) = msg;
      try {
        final result = await logic.onRequest(payload);
        replyTo.send((id, result));
      } catch (e, st) {
        replyTo.send((id, RemoteError(e.toString(), st.toString())));
      }
      return;
    }

    // Fire-and-forget
    try {
      await logic.onMessage(msg);
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(
          SentryLevel.error, 'Isolate error while handling message',
          exception: exception,
          stackTrace: stackTrace,
          logger: config.debugName);
    }
  });
}
