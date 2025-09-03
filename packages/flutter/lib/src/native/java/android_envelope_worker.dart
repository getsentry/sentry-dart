import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../worker_isolate.dart';
import '../../isolate_diagnostic_log.dart';
import 'binding.dart' as native;

class AndroidEnvelopeWorker implements WorkerHandle {
  final SentryFlutterOptions _options;
  final IsolateConfig _config;
  IsolateClient? _client;

  AndroidEnvelopeWorker(this._options)
      : _config = IsolateConfig(
          debug: _options.debug,
          logLevel: _options.diagnosticLevel,
          debugName: 'SentryAndroidEnvelopeWorker',
        );

  @internal // visible for testing/mocking
  static AndroidEnvelopeWorker Function(SentryFlutterOptions) factory =
      AndroidEnvelopeWorker.new;

  @override
  FutureOr<void> start() async {
    if (_client != null) return;
    _client = await spawnIsolate(_config, _entryPoint);
  }

  static void _entryPoint((SendPort, IsolateConfig) init) {
    final (host, config) = init;
    runIsolate(config, host, _AndroidEnvelopeMessageHandler());
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    final client = _client;
    if (client == null) {
      _options.log(
        SentryLevel.warning,
        'AndroidEnvelopeWorker.captureEnvelope called before start; dropping',
      );
      return;
    }
    client.send((
      TransferableTypedData.fromList([envelopeData]),
      containsUnhandledException
    ));
  }

  @override
  FutureOr<void> close() {
    _client?.close();
    _client = null;
  }
}

class _AndroidEnvelopeMessageHandler implements IsolateMessageHandler {
  @override
  FutureOr<void> onMessage(Object? msg) {
    if (msg is (TransferableTypedData, bool)) {
      final (transferable, containsUnhandledException) = msg;
      final data = transferable.materialize().asUint8List();
      _captureEnvelope(data, containsUnhandledException);
    } else {
      IsolateDiagnosticLog.log(SentryLevel.warning,
          'Unexpected message type while handling a message: $msg',
          logger: 'SentryAndroidEnvelopeWorker');
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
        IsolateDiagnosticLog.log(SentryLevel.error,
            'Native Android SDK returned null id when capturing envelope',
            logger: 'SentryAndroidEnvelopeWorker');
      }
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception,
          stackTrace: stackTrace,
          logger: 'SentryAndroidEnvelopeWorker');
      // TODO:
      // if (options.automatedTestMode) {
      //   rethrow;
      // }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }

  @override
  FutureOr<Object?> onRequest(Object? payload) => null; // not used for now
}
