import 'dart:developer' as developer;
import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

class WorkerConfig {
  final bool debug;
  final SentryLevel logLevel;
  final String? debugName;

  const WorkerConfig({
    required this.debug,
    required this.logLevel,
    this.debugName,
  });
}

class IsolateDiagnosticLog {
  IsolateDiagnosticLog._();

  static late final bool _debug;
  static late final SentryLevel _level;

  static void configure({required bool debug, required SentryLevel level}) {
    _debug = debug;
    _level = level;
  }

  static void log(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (_isEnabled(level)) {
      developer.log(
        '[${level.name}] $message',
        level: level.toDartLogLevel(),
        name: logger ?? 'sentry',
        time: DateTime.now(),
        error: exception,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _isEnabled(SentryLevel level) {
    return _debug && level.ordinal >= _level.ordinal ||
        level == SentryLevel.fatal;
  }
}

/// Unified V3 worker API combining the robustness of the native replay worker
/// pattern (request/response with correlation IDs) with the minimal
/// WorkerIsolateBase bootstrap/spawn flow.
abstract class WorkerIsolate {
  static const String shutdownMessage = 'shutdown';

  @protected
  final SendPort hostPort;

  WorkerIsolate(this.hostPort);

  /// Handle fire-and-forget messages from host → worker.
  FutureOr<void> handleMessage(Object? message);

  /// Handle a request expecting a response. Default implementation returns null.
  FutureOr<Object?> handleRequest(Object? payload) => null;

  /// Worker-side bootstrap: configures logging, handshakes, starts loop.
  static void bootstrap(
    WorkerConfig config,
    SendPort hostPort,
    WorkerIsolate worker,
  ) {
    IsolateDiagnosticLog.configure(
      debug: config.debug,
      level: config.logLevel,
    );
    final receivePort = ReceivePort();

    // Handshake: provide worker's inbox to host.
    hostPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message == shutdownMessage) {
        IsolateDiagnosticLog.log(
            SentryLevel.debug, 'Worker V3 received shutdown request');
        try {
          receivePort.close();
        } catch (e, st) {
          IsolateDiagnosticLog.log(
            SentryLevel.error,
            'Worker V3 ReceivePort close error',
            exception: e,
            stackTrace: st,
          );
        }
        IsolateDiagnosticLog.log(SentryLevel.debug, 'Worker V3 closed');
        return;
      }

      // Minimal RPC pattern: (id, payload, replyTo)
      if (message is (int, Object?, SendPort)) {
        final (id, payload, replyTo) = message;
        Future.sync(() => worker.handleRequest(payload))
            .then((result) => replyTo.send((id, result)))
            .catchError((Object error, StackTrace stackTrace) {
          // RemoteError is a simple, transferable error container.
          replyTo
              .send((id, RemoteError(error.toString(), stackTrace.toString())));
        });
        return;
      }

      // Fire-and-forget path
      try {
        worker.handleMessage(message);
      } catch (e, st) {
        IsolateDiagnosticLog.log(
          SentryLevel.error,
          'Worker V3 error while handling message',
          exception: e,
          stackTrace: st,
        );
      }
    });
  }

  /// Host-side spawn: returns worker inbox SendPort after handshake
  static Future<(Isolate isolate, SendPort workerPort)> spawn(
    WorkerConfig cfg,
    void Function((WorkerConfig, SendPort)) entryPoint,
  ) async {
    final init = ReceivePort();
    final isolate = await Isolate.spawn<(WorkerConfig, SendPort)>(
      entryPoint,
      (cfg, init.sendPort),
      debugName: cfg.debugName,
    );
    final SendPort workerPort = await init.first as SendPort;
    return (isolate, workerPort);
  }
}

/// Host-side helper for workers to perform minimal request/response.
class WorkerClient {
  WorkerClient(this._workerPort) {
    _responses.listen(_handleResponse);
  }

  final SendPort _workerPort;
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
    if (_closed) throw StateError('WorkerClientV3 is closed');
    final id = _idCounter++;
    final completer = Completer<Object?>.sync();
    _pending[id] = completer;
    _workerPort.send((id, payload, _responses.sendPort));
    return completer.future;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _workerPort.send(WorkerIsolate.shutdownMessage);
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
