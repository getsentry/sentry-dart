import 'dart:async';
import 'dart:isolate';

import '../sentry_flutter.dart';
import 'isolate_diagnostic_log.dart';

// -------------------------------------------
// HOST-SIDE API (runs on the main isolate)
// -------------------------------------------

/// Host-side lifecycle interface for a worker isolate.
///
/// Responsible for spawning the worker isolate, sending messages,
/// and shutting it down. It does not define the worker logic.
abstract class WorkerHost {
  FutureOr<void> start();
  FutureOr<void> close();
}

/// Minimal config passed to isolates. Extend as needed.
class WorkerConfig {
  final String? debugName;

  const WorkerConfig({
    required this.debugName,
  });
}

/// Host-side helper for workers to perform minimal request/response.
class Worker {
  Worker(this._workerPort) {
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
    if (_closed) throw StateError('WorkerClient is closed');
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

/// Worker (isolate) entry-point signature.
typedef WorkerEntry = void Function((SendPort, WorkerConfig));

/// Spawn a worker isolate and handshake to obtain its SendPort.
Future<Worker> spawnWorker(
  WorkerConfig config,
  WorkerEntry entry,
) async {
  final receivePort = ReceivePort();
  await Isolate.spawn<(SendPort, WorkerConfig)>(
    entry,
    (receivePort.sendPort, config),
    debugName: config.debugName,
  );
  final workerPort = await receivePort.first as SendPort;
  return Worker(workerPort);
}

// -------------------------------------------
// ISOLATE-SIDE API (runs inside the worker isolate)
// -------------------------------------------

/// Message/request handler that runs inside the worker isolate.
///
/// This does not represent the isolate lifecycle; it only defines how
/// the worker processes incoming messages and optional request/response.
abstract class WorkerHandler {
  /// Handle fire-and-forget messages sent from the host.
  FutureOr<void> onMessage(Object? message);

  /// Handle request/response payloads sent from the host.
  /// Return value is sent back to the host. Default: no-op.
  FutureOr<Object?> onRequest(Object? payload) => {};
}

/// Generic worker runtime. Reuse for every Sentry worker.
void runWorker(
  WorkerConfig config,
  SendPort host,
  WorkerHandler handler,
) {
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
        final result = await handler.onRequest(payload);
        replyTo.send((id, result));
      } catch (e, st) {
        replyTo.send((id, RemoteError(e.toString(), st.toString())));
      }
      return;
    }

    // Fire-and-forget
    try {
      await handler.onMessage(msg);
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(
          SentryLevel.error, 'Isolate error while handling message',
          exception: exception,
          stackTrace: stackTrace,
          logger: config.debugName);
    }
  });
}
