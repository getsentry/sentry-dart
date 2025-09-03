import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../worker_isolate.dart';
import 'binding.dart' as native;

/// Host-side proxy for the Android envelope worker isolate.
class AndroidEnvelopeWorker {
  AndroidEnvelopeWorker(this._options);

  final SentryFlutterOptions _options;

  WorkerClient? _client;

  @internal // visible for testing/mocking
  static AndroidEnvelopeWorker Function(SentryFlutterOptions) factory =
      AndroidEnvelopeWorker.new;

  Future<void> start() async {
    if (_client != null) return;
    final config = WorkerConfig(
      debug: _options.debug,
      logLevel: _options.diagnosticLevel,
      debugName: 'SentryAndroidEnvelopeWorker',
    );
    final (_, port) = await WorkerIsolate.spawn(
      config,
      AndroidEnvelopeWorkerIsolate.entryPoint,
    );
    _client = WorkerClient(port);
  }

  Future<void> stop() async {
    _close();
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(Uint8List envelopeData) {
    final client = _client;
    if (client == null) {
      _options.log(
        SentryLevel.warning,
        'AndroidEnvelopeWorker.captureEnvelope called before start; dropping',
      );
      return;
    }
    client.send(TransferableTypedData.fromList([envelopeData]));
  }

  void _close() {
    _client?.close();
    _client = null;
  }
}

/// Worker isolate implementation handling envelope capture via JNI.
class AndroidEnvelopeWorkerIsolate extends WorkerIsolate {
  AndroidEnvelopeWorkerIsolate(super.host);

  @override
  FutureOr<void> handleMessage(Object? message) {
    IsolateDiagnosticLog.log(SentryLevel.warning,
        'EnvelopeWorker invoked; starting captureEnvelope');

    if (message is TransferableTypedData) {
      final envelopeData = message.materialize().asUint8List();
      _captureEnvelope(envelopeData, false);
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
            'Native Android SDK returned null id when capturing envelope');
      }
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);
      // if (options.automatedTestMode) {
      //   rethrow;
      // }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }

  static void entryPoint((WorkerConfig, SendPort) args) {
    final (config, host) = args;
    WorkerIsolate.bootstrap(config, host, AndroidEnvelopeWorkerIsolate(host));
  }
}
