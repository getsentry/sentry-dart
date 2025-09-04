import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../isolate/isolate_logger.dart';
import 'binding.dart' as cocoa;

typedef SpawnWorkerFn = Future<Worker> Function(WorkerConfig, WorkerEntry);

class CocoaEnvelopeSender {
  final SentryFlutterOptions _options;
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;
  Worker? _worker;

  CocoaEnvelopeSender(this._options, {SpawnWorkerFn? spawn})
      : _config = WorkerConfig(
          debugName: 'SentryCocoaEnvelopeSender',
          debug: _options.debug,
          diagnosticLevel: _options.diagnosticLevel,
        ),
        _spawn = spawn ?? spawnWorker;

  @internal // visible for testing/mocking
  static CocoaEnvelopeSender Function(SentryFlutterOptions) factory =
      CocoaEnvelopeSender.new;

  FutureOr<void> start() async {
    if (_worker != null) return;
    _worker = await _spawn(_config, _entryPoint);
  }

  FutureOr<void> close() {
    _worker?.close();
    _worker = null;
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(Uint8List envelopeData) {
    final client = _worker;
    if (client == null) {
      _options.log(
        SentryLevel.warning,
        'captureEnvelope called before start; dropping',
      );
      return;
    }
    client.send(TransferableTypedData.fromList([envelopeData]));
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(config, host, _CocoaEnvelopeHandler());
  }
}

class _CocoaEnvelopeHandler extends WorkerHandler {
  @override
  FutureOr<void> onMessage(Object? msg) {
    if (msg is TransferableTypedData) {
      final data = msg.materialize().asUint8List();
      _captureEnvelope(data);
    } else {
      IsolateLogger.log(SentryLevel.warning, 'Unexpected message type: $msg');
    }
  }

  void _captureEnvelope(Uint8List envelopeData) {
    try {
      final nsData = envelopeData.toNSData();
      final envelope = cocoa.PrivateSentrySDKOnly.envelopeWithData(nsData);
      if (envelope != null) {
        cocoa.PrivateSentrySDKOnly.captureEnvelope(envelope);
      } else {
        IsolateLogger.log(SentryLevel.error,
            'Native Cocoa SDK returned null when capturing envelope');
      }
    } catch (exception, stackTrace) {
      IsolateLogger.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);
    }
  }
}
