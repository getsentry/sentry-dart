import 'dart:async';
import 'dart:isolate';

import '../../sentry_flutter.dart';
import 'isolate_logger.dart';

const _shutdownCommand = '_shutdown_';

// -------------------------------------------
// HOST-SIDE API (runs on the main isolate)
// -------------------------------------------

/// Minimal config passed to isolates. Extend as needed.
class WorkerConfig {
  final bool debug;
  final SentryLevel diagnosticLevel;
  final String? debugName;

  const WorkerConfig({
    required this.debug,
    required this.diagnosticLevel,
    required this.debugName,
  });
}

/// Host-side lifecycle interface for a worker isolate.
///
/// Responsible for spawning the worker isolate, and shutting it down.
/// It does not define the worker logic.
abstract class WorkerHost {
  FutureOr<void> start();
  FutureOr<void> close();
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
    if (_closed) throw StateError('Worker is closed');
    final id = _idCounter++;
    final completer = Completer<Object?>.sync();
    _pending[id] = completer;
    _workerPort.send((id, payload, _responses.sendPort));
    return completer.future;
  }

  void close() {
    if (_closed) return;
    _workerPort.send(_shutdownCommand);
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

/// Runs the Sentry worker loop inside a background isolate.
///
/// Call this only from the worker isolate entry-point spawned via
/// [spawnWorker]. It configures logging, handshakes with the host, and routes
/// messages
void runWorker(
  WorkerConfig config,
  SendPort host,
  WorkerHandler handler,
) {
  IsolateLogger.configure(
    debug: config.debug,
    level: config.diagnosticLevel,
    loggerName: config.debugName ?? 'SentryIsolateWorker',
  );

  final inbox = ReceivePort();
  host.send(inbox.sendPort);

  inbox.listen((msg) async {
    if (msg == _shutdownCommand) {
      IsolateLogger.log(SentryLevel.debug, 'Isolate received shutdown');
      inbox.close();
      IsolateLogger.log(SentryLevel.debug, 'Isolate closed');
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
      IsolateLogger.log(SentryLevel.error, 'Isolate failed to handle message',
          exception: exception, stackTrace: stackTrace);
    }
  });
}
