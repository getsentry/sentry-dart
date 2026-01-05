import 'dart:async';
import 'dart:isolate';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';

typedef SpawnWorkerFn = Future<Worker> Function(WorkerConfig, WorkerEntry);

const _shutdownCommand = '_shutdown_';

// -------------------------------------------
// HOST-SIDE API (runs on the main isolate)
// -------------------------------------------

/// Minimal config passed to isolates - extend as needed.
class WorkerConfig {
  final bool debug;
  final SentryLevel diagnosticLevel;
  final String debugName;
  final bool automatedTestMode;

  const WorkerConfig({
    required this.debug,
    required this.diagnosticLevel,
    required this.debugName,
    this.automatedTestMode = false,
  });
}

/// Host-side helper for workers to perform minimal request/response.
/// Adapted from https://dart.dev/language/isolates#robust-ports-example
class Worker {
  Worker(this._workerPort, this._responses) {
    _responses.listen(_handleResponse);
  }

  final SendPort _workerPort;
  SendPort get port => _workerPort;
  final ReceivePort _responses;
  final Map<int, Completer<Object?>> _pending = {};
  int _idCounter = 0;
  bool _closed = false;

  /// Fire-and-forget send to the worker.
  void send(Object? message) {
    _workerPort.send(message);
  }

  /// Send a request to the worker and await a response.
  Future<Object?> request(Object? payload) async {
    if (_closed) throw StateError('Worker is closed');
    final id = _idCounter++;
    final completer = Completer<Object?>.sync();
    _pending[id] = completer;
    _workerPort.send((id, payload));
    return await completer.future;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _workerPort.send(_shutdownCommand);
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
  final initPort = RawReceivePort();
  final connection = Completer<(ReceivePort, SendPort)>.sync();
  initPort.handler = (SendPort commandPort) {
    connection.complete((
      ReceivePort.fromRawReceivePort(initPort),
      commandPort,
    ));
  };

  try {
    await Isolate.spawn<(SendPort, WorkerConfig)>(
      entry,
      (initPort.sendPort, config),
      debugName: config.debugName,
    );
  } on Object {
    initPort.close();
    rethrow;
  }

  final (ReceivePort receivePort, SendPort sendPort) = await connection.future;
  return Worker(sendPort, receivePort);
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
  // ignore: invalid_use_of_internal_member
  SentryInternalLogger.configure(
      isEnabled: config.debug, minLevel: config.diagnosticLevel);

  final inbox = ReceivePort();
  host.send(inbox.sendPort);

  inbox.listen((msg) async {
    if (msg == _shutdownCommand) {
      debugLogger.debug('${config.debugName}: isolate received shutdown');
      inbox.close();
      debugLogger.debug('${config.debugName}: isolate closed');
      return;
    }

    if (msg is (int, Object?)) {
      final (id, payload) = msg;
      try {
        final result = await handler.onRequest(payload);
        host.send((id, result));
      } catch (e, st) {
        host.send((id, RemoteError(e.toString(), st.toString())));
      }
      return;
    }

    try {
      await handler.onMessage(msg);
    } catch (exception, stackTrace) {
      debugLogger.error('${config.debugName}: isolate failed to handle message',
          error: exception, stackTrace: stackTrace);
    }
  });
}
