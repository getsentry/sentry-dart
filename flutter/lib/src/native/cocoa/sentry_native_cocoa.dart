import 'dart:async';
import 'dart:ffi';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  late final _lib = cocoa.SentryCocoa(DynamicLibrary.process());
  CocoaReplayRecorder? _replayRecorder;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??= CocoaReplayRecorder(options);

            final replayId = call.arguments['replayId'] == null
                ? null
                : SentryId.fromId(call.arguments['replayId'] as String);

            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // ignore: invalid_use_of_internal_member
                s.replayId = replayId;
              });
            }

            return _replayRecorder!.captureScreenshot();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  // private func captureEnvelope(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  // guard let arguments = call.arguments as? [Any],
  // !arguments.isEmpty,
  // let data = (arguments.first as? FlutterStandardTypedData)?.data else {
  // print("Envelope is null or empty!")
  // result(FlutterError(code: "2", message: "Envelope is null or empty", details: nil))
  // return
  // }
  // guard let envelope = PrivateSentrySDKOnly.envelope(with: data) else {
  // print("Cannot parse the envelope data")
  // result(FlutterError(code: "3", message: "Cannot parse the envelope data", details: nil))
  // return
  // }

  @override
  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) async {
    // 1. Allocate a native Uint8 buffer of the needed length
    // final length = envelopeData.length;
    // final ptr = malloc<ffi.Uint8>(length);

    final stopwatch = Stopwatch()..start();

    cocoa.NSData nsData;
    try {
      // 1) allocate & copy into C heap, then hand it off to Cocoa (copy semantics)
      nsData = envelopeData.toFfiNSDataCopy(_lib);

      // 2) wrap that NSData in a Sentry envelope
      final envelope =
          cocoa.PrivateSentrySDKOnly.envelopeWithData_(_lib, nsData);

      // 3) finally, send it off
      cocoa.PrivateSentrySDKOnly.captureEnvelope_(_lib, envelope);
    } catch (error, stackTrace) {
      debugPrint('🔴 captureEnvelope failed: $error\n$stackTrace');
    }

    stopwatch.stop();

    final stopwatch2 = Stopwatch()..start();

    await super.captureEnvelope(envelopeData, containsUnhandledException);

    stopwatch2.stop();

    return Future.value();
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    // Note: unused on iOS.
  }

  @override
  int? startProfiler(SentryId traceId) => tryCatchSync('startProfiler', () {
        final cSentryId = cocoa.SentryId1.alloc(_lib)
          ..initWithUUIDString_(cocoa.NSString(_lib, traceId.toString()));
        final startTime =
            cocoa.PrivateSentrySDKOnly.startProfilerForTrace_(_lib, cSentryId);
        return startTime;
      });
}

extension Uint8ListFfi on Uint8List {
  /// Allocates a native buffer, copies [this] into it,
  /// and wraps it in an NSData (copy‑on‑write) so we can free the ptr immediately.
  cocoa.NSData toFfiNSDataCopy(cocoa.SentryCocoa lib) {
    // A) malloc a Uint8 buffer
    final ptr = malloc<ffi.Uint8>(length);

    // B) copy your Dart bytes into the native buffer
    ptr.asTypedList(length).setAll(0, this);

    // C) ask Cocoa to copy INTO its own NSData
    final data = cocoa.NSData.dataWithBytes_length_(
      lib,
      ptr.cast<ffi.Void>(),
      length,
    );

    // D) free our malloc right away—NSData has already made its own copy
    malloc.free(ptr);

    return data;
  }
}
