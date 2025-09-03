import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../worker_isolate.dart';
import '../../isolate_diagnostic_log.dart';
import 'binding.dart' as native;

class AndroidEnvelopeSender implements WorkerHost {
  final SentryFlutterOptions _options;
  final WorkerConfig _config;
  Worker? _worker;

  static final String name = 'SentryAndroidEnvelopeSender';

  AndroidEnvelopeSender(this._options)
      : _config = WorkerConfig(
          debugName: name,
        );

  @internal // visible for testing/mocking
  static AndroidEnvelopeSender Function(SentryFlutterOptions) factory =
      AndroidEnvelopeSender.new;

  @override
  FutureOr<void> start() async {
    if (_worker != null) return;
    _worker = await spawnWorker(_config, _entryPoint);
  }

  @override
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
        SentryLevel.warning,
        'captureEnvelope called before worker started; dropping',
        logger: name,
      );
      return;
    }
    client.send((
      TransferableTypedData.fromList([envelopeData]),
      containsUnhandledException
    ));
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(config, host, _AndroidEnvelopeHandler());
  }
}

class _AndroidEnvelopeHandler extends WorkerHandler {
  @override
  FutureOr<void> onMessage(Object? msg) {
    if (msg is (TransferableTypedData, bool)) {
      final (transferable, containsUnhandledException) = msg;
      final data = transferable.materialize().asUint8List();
      _captureEnvelope(data, containsUnhandledException);
    } else {
      IsolateDiagnosticLog.log(SentryLevel.warning,
          'Unexpected message type while handling a message: $msg',
          logger: AndroidEnvelopeSender.name);
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
            logger: AndroidEnvelopeSender.name);
      }
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception,
          stackTrace: stackTrace,
          logger: AndroidEnvelopeSender.name);
      // TODO:
      // if (options.automatedTestMode) {
      //   rethrow;
      // }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }
}
