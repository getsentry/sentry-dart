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

  /// Requests that the worker shut itself down when the calling isolate
  /// exits - even an abrupt exit, such as its isolate group being torn down
  /// - rather than relying on a Dart-level callback that may never get a
  /// chance to run in that isolate again.
  ///
  /// Call this from the isolate that owns this [Worker] (i.e. the one that
  /// obtained it from [spawnWorker]). Unlike a callback tied to a host
  /// engine/view detaching, this only fires when that owning isolate is
  /// actually gone, so a worker survives a cached engine detaching and
  /// later reattaching to a new host view.
  void closeOnOwnerExit() {
    Isolate.current.addOnExitListener(_workerPort, response: _shutdownCommand);
  }

  /// Asks the worker to shut down.
  ///
  /// With [exitToken], the worker presents the token to its exit request
  /// function once everything sent before this call was handled, provided
  /// its handler follows the two rules on [WorkerHandler], and only exits if
  /// that grants it. See [runWorker].
  void close({int? exitToken}) {
    if (_closed) return;
    _closed = true;
    // Harmless no-op if closeOnOwnerExit() was never called for this port.
    Isolate.current.removeOnExitListener(_workerPort);
    _workerPort.send(
      exitToken == null ? _shutdownCommand : (_shutdownCommand, exitToken),
    );
    if (_pending.isEmpty) {
      _responses.close();
    }
  }

  /// Closes the worker because its engine is about to be destroyed.
  ///
  /// Whoever holds up engine teardown, on Android the plugin's
  /// `WorkerExitGate`, waits for every worker announced with [armExit] to ask
  /// for its exit. A worker closed with [exitToken] that asks too late is
  /// never allowed to exit: it would be the last isolate of its group and
  /// release Flutter's GPU objects after the engine is gone (#4092).
  ///
  /// Synchronous on purpose: the calling isolate gets no further turn before
  /// the wait starts.
  void closeForEngineDetach(int exitToken, ArmWorkerExitFn armExit) {
    try {
      armExit(exitToken);
    } catch (exception, stackTrace) {
      // Nothing waits for this worker then. Closing it with the token still
      // keeps it from exiting once the wait is over.
      internalLogger.error(
        'Failed to arm worker exit',
        error: exception,
        stackTrace: stackTrace,
      );
    }
    close(exitToken: exitToken);
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
Future<Worker> spawnWorker(WorkerConfig config, WorkerEntry entry) async {
  final initPort = RawReceivePort();
  final connection = Completer<(ReceivePort, SendPort)>.sync();
  initPort.handler = (SendPort commandPort) {
    connection.complete((
      ReceivePort.fromRawReceivePort(initPort),
      commandPort,
    ));
  };

  try {
    await Isolate.spawn<(SendPort, WorkerConfig)>(entry, (
      initPort.sendPort,
      config,
    ), debugName: config.debugName);
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
///
/// Two rules keep a worker safe to stop while its engine is being destroyed,
/// see the `requestExit` parameter of [runWorker]:
///
/// - Never wait on the platform's main looper. The platform thread is
///   blocked until the worker has asked to exit, so such a wait only ends
///   when the platform gives up on the worker.
/// - Finish the work for a message synchronously or in microtasks. Work that
///   still waits for a timer or I/O when the shutdown arrives keeps the
///   isolate alive after it was allowed to exit.
abstract class WorkerHandler {
  /// Handle fire-and-forget messages sent from the host.
  FutureOr<void> onMessage(Object? message);

  /// Handle request/response payloads sent from the host.
  /// Return value is sent back to the host. Default: no-op.
  FutureOr<Object?> onRequest(Object? payload) => {};

  /// Releases what the handler holds, right before the worker stops handling
  /// messages.
  ///
  /// Must be synchronous. Default: no-op.
  void onShutdown() {}
}

/// Asks whoever holds up engine teardown whether the calling worker isolate
/// may exit.
///
/// See [runWorker].
typedef RequestWorkerExitFn = bool Function(int exitToken);

/// Tells whoever holds up engine teardown to expect one worker's exit request.
typedef ArmWorkerExitFn = void Function(int exitToken);

/// Runs the Sentry worker loop inside a background isolate.
///
/// Call this only from the worker isolate entry-point spawned via
/// [spawnWorker]. It configures logging, handshakes with the host, and routes
/// messages
///
/// When the host closes the worker with an exit token, [requestExit] is
/// called once with that token, after everything sent earlier was handled,
/// provided [handler] follows the two rules on [WorkerHandler]. If it returns
/// false or throws, exiting is no longer safe: the isolate stays alive for
/// the rest of the process and ignores every later message. [requestExit]
/// should rather block than return false, since the runtime can still
/// collect garbage and run finalizers for the group of an idle isolate.
void runWorker(
  WorkerConfig config,
  SendPort host,
  WorkerHandler handler, {
  RequestWorkerExitFn? requestExit,
}) {
  // ignore: invalid_use_of_internal_member
  SentryInternalLogger.configure(
    isEnabled: config.debug,
    minLevel: config.diagnosticLevel,
  );

  final inbox = ReceivePort();
  host.send(inbox.sendPort);

  var parked = false;

  void shutDown(int? exitToken) {
    internalLogger.debug('${config.debugName}: isolate received shutdown');
    try {
      handler.onShutdown();
    } catch (exception, stackTrace) {
      internalLogger.error(
        '${config.debugName}: isolate failed to run its shutdown hook',
        error: exception,
        stackTrace: stackTrace,
      );
    }

    var mayExit = true;
    if (exitToken != null && requestExit != null) {
      try {
        mayExit = requestExit(exitToken);
      } catch (exception, stackTrace) {
        mayExit = false;
        internalLogger.error(
          '${config.debugName}: isolate failed to request its exit',
          error: exception,
          stackTrace: stackTrace,
        );
      }
    }
    if (!mayExit) {
      // The open inbox is what keeps the isolate alive.
      parked = true;
      internalLogger.warning(
        '${config.debugName}: isolate stays alive, exiting is no longer safe',
      );
      return;
    }

    inbox.close();
    internalLogger.debug('${config.debugName}: isolate closed');
  }

  inbox.listen((msg) async {
    if (parked) return;

    if (msg == _shutdownCommand) {
      shutDown(null);
      return;
    }
    if (msg case (_shutdownCommand, final int exitToken)) {
      shutDown(exitToken);
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
      internalLogger.error(
        '${config.debugName}: isolate failed to handle message',
        error: exception,
        stackTrace: stackTrace,
      );
    }
  });
}
