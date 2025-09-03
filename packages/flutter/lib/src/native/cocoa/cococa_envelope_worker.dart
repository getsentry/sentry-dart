import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../worker_isolate.dart';
import '../../isolate_diagnostic_log.dart';
import 'binding.dart' as cocoa;

class CocoaEnvelopeWorker implements Worker {
  final SentryFlutterOptions _options;
  final IsolateConfig _config;
  IsolateClient? _client;

  CocoaEnvelopeWorker(this._options)
      : _config = IsolateConfig(
          debug: _options.debug,
          logLevel: _options.diagnosticLevel,
          debugName: 'SentryCocoaEnvelopeWorker',
        );

  @internal // visible for testing/mocking
  static CocoaEnvelopeWorker Function(SentryFlutterOptions) factory =
      CocoaEnvelopeWorker.new;

  @override
  FutureOr<void> start() async {
    if (_client != null) return;
    _client = await spawnIsolate(_config, _entryPoint);
  }

  static void _entryPoint((SendPort, IsolateConfig) init) {
    final (host, config) = init;
    runIsolate(config, host, _CocoaEnvelopeMessageHandler());
  }

  /// Fire-and-forget send of envelope bytes to the worker.
  void captureEnvelope(Uint8List envelopeData) {
    final client = _client;
    if (client == null) {
      _options.log(
        SentryLevel.warning,
        'CocoaEnvelopeWorker.captureEnvelope called before start; dropping',
      );
      return;
    }
    client.send(TransferableTypedData.fromList([envelopeData]));
  }

  @override
  FutureOr<void> close() {
    _client?.close();
    _client = null;
  }
}

class _CocoaEnvelopeMessageHandler extends IsolateMessageHandler {
  @override
  FutureOr<void> onMessage(Object? msg) {
    if (msg is TransferableTypedData) {
      final data = msg.materialize().asUint8List();
      _captureEnvelope(data);
    } else {
      IsolateDiagnosticLog.log(SentryLevel.warning,
          'Unexpected message type while handling a message: $msg',
          logger: 'SentryCocoaEnvelopeWorker');
    }
  }

  void _captureEnvelope(Uint8List envelopeData) {
    JObject? id;
    JByteArray? byteArray;
    try {
      final nsData = envelopeData.toNSData();
      final envelope = cocoa.PrivateSentrySDKOnly.envelopeWithData(nsData);
      if (envelope != null) {
        cocoa.PrivateSentrySDKOnly.captureEnvelope(envelope);
      } else {
        IsolateDiagnosticLog.log(SentryLevel.error,
            'Native Cocoa SDK returned null when capturing envelope',
            logger: 'SentryCocoaEnvelopeWorker');
      }
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception,
          stackTrace: stackTrace,
          logger: 'SentryCocoaEnvelopeWorker');
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
