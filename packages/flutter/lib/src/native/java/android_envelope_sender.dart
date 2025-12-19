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
  final List<(Uint8List, bool)> _pendingEnvelopes = [];

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
    if (_worker != null) return;
    _worker = await _spawn(_config, _entryPoint);

    if (_pendingEnvelopes.isNotEmpty) {
      // The worker is now ready - we can flush the pending envelopes.
      for (final envelope in _pendingEnvelopes) {
        captureEnvelope(envelope.$1, envelope.$2);
      }
      _pendingEnvelopes.clear();

      _options.log(SentryLevel.info, 'Flushed pending envelopes');
    }
  }

  FutureOr<void> close() {
    _worker?.close();
    _worker = null;
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    final client = _worker;
    if (client == null) {
      _options.log(
        SentryLevel.info,
        'captureEnvelope called before worker started: buffering envelope',
      );
      _pendingEnvelopes.add((envelopeData, containsUnhandledException));
      return;
    }
    client.send((
      TransferableTypedData.fromList([envelopeData]),
      containsUnhandledException
    ));
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
      _captureEnvelope(data, containsUnhandledException);
    } else {
      IsolateLogger.log(SentryLevel.warning, 'Unexpected message type: $msg');
    }
  }

  void _captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    JObject? id;
    JByteArray? byteArray;
    try {
      byteArray = JByteArray.from(envelopeData);
      id = native.InternalSentrySdk.captureEnvelope(
          byteArray, containsUnhandledException);

      if (id == null) {
        IsolateLogger.log(SentryLevel.error,
            'Native Android SDK returned null when capturing envelope');
      }
    } catch (exception, stackTrace) {
      IsolateLogger.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);
      if (_config.automatedTestMode) {
        rethrow;
      }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }
}
