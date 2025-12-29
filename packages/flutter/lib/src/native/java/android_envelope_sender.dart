import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../isolate/isolate_logger.dart';
import 'binding.dart' as native;

class AndroidEnvelopeSender {
  final SentryFlutterOptions _options;
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;
  bool _isClosed = false;

  Worker? _worker;

  AndroidEnvelopeSender(this._options, {SpawnWorkerFn? spawn})
      : _config = WorkerConfig(
          debugName: 'SentryAndroidEnvelopeSender',
          debug: _options.debug,
          diagnosticLevel: _options.diagnosticLevel,
          automatedTestMode: _options.automatedTestMode,
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
      _options.log(
        SentryLevel.info,
        'captureEnvelope called before worker started: sending envelope in main isolate instead',
      );
      _captureEnvelope(envelopeData, containsUnhandledException,
          automatedTestMode: _config.automatedTestMode, logger: _options.log);
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
          automatedTestMode: _config.automatedTestMode,
          logger: IsolateLogger.log);
    } else {
      IsolateLogger.log(SentryLevel.warning, 'Unexpected message type: $msg');
    }
  }
}

void _captureEnvelope(Uint8List envelopeData, bool containsUnhandledException,
    {bool automatedTestMode = false, required SdkLogCallback logger}) {
  JObject? id;
  JByteArray? byteArray;
  try {
    byteArray = JByteArray.from(envelopeData);
    id = native.InternalSentrySdk.captureEnvelope(
        byteArray, containsUnhandledException);

    if (id == null) {
      logger(SentryLevel.error,
          'Native Android SDK returned null when capturing envelope');
    }
  } catch (exception, stackTrace) {
    logger(SentryLevel.error, 'Failed to capture envelope',
        exception: exception, stackTrace: stackTrace);
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    byteArray?.release();
    id?.release();
  }
}
