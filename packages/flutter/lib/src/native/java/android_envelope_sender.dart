import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../utils/internal_logger.dart';
import 'binding.dart' as native;

class AndroidEnvelopeSender {
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;

  bool _isClosed = false;
  Worker? _worker;

  AndroidEnvelopeSender(SentryOptions options, {SpawnWorkerFn? spawn})
      : _config = WorkerConfig(
          debugName: 'SentryAndroidEnvelopeSender',
          debug: options.debug,
          diagnosticLevel: options.diagnosticLevel,
          // ignore: invalid_use_of_internal_member
          automatedTestMode: options.automatedTestMode,
        ),
        _spawn = spawn ?? spawnWorker;

  @internal
  static AndroidEnvelopeSender Function(SentryFlutterOptions) factory =
      AndroidEnvelopeSender.new;

  FutureOr<void> start() async {
    if (_isClosed) return;
    if (_worker != null) return;
    final worker = await _spawn(_config, _entryPoint);
    // Guard against close() being called during spawn.
    if (_isClosed) {
      worker.close();
      return;
    }
    _worker = worker;
  }

  FutureOr<void> close() {
    _worker?.close();
    _worker = null;
    _isClosed = true;
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    if (_isClosed) return;

    final client = _worker;
    if (client != null) {
      client.send((
        TransferableTypedData.fromList([envelopeData]),
        containsUnhandledException
      ));
    } else {
      internalLogger.info(
        'captureEnvelope called before worker started: sending envelope in main isolate instead',
      );
      _captureEnvelope(envelopeData, containsUnhandledException,
          automatedTestMode: _config.automatedTestMode);
    }
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(config, host, _AndroidEnvelopeHandler(config));
  }
}

class _AndroidEnvelopeHandler extends WorkerHandler {
  final WorkerConfig _config;

  _AndroidEnvelopeHandler(this._config);

  @override
  FutureOr<void> onMessage(Object? msg) {
    if (msg is (TransferableTypedData, bool)) {
      final (transferable, containsUnhandledException) = msg;
      final data = transferable.materialize().asUint8List();
      _captureEnvelope(data, containsUnhandledException,
          automatedTestMode: _config.automatedTestMode);
    } else {
      internalLogger
          .warning('${_config.debugName}: unexpected message type: $msg');
    }
  }
}

void _captureEnvelope(Uint8List envelopeData, bool containsUnhandledException,
    {bool automatedTestMode = false}) {
  JObject? id;
  JByteArray? byteArray;
  try {
    byteArray = JByteArray.from(envelopeData);
    id = native.InternalSentrySdk.captureEnvelope(
        byteArray, containsUnhandledException);

    if (id == null) {
      internalLogger
          .error('Native Android SDK returned null when capturing envelope');
    }
  } catch (exception, stackTrace) {
    internalLogger.error('Failed to capture envelope',
        error: exception, stackTrace: stackTrace);
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    byteArray?.release();
    id?.release();
  }
}
