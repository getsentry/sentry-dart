import 'dart:async';
import 'dart:ffi';

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
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    // Use a safe copy-based conversion to avoid double-free issues observed
    // when relying on `dataWithBytesNoCopy:length:freeWhenDone:`. Although
    // this involves an additional copy, it prevents the EXC_BAD_ACCESS
    // crash caused by Cocoa freeing the buffer twice.
    final length = envelopeData.length;
    final ptr = malloc<Uint8>(length);
    ptr.asTypedList(length).setAll(0, envelopeData);
    try {
      final nsData =
          cocoa.NSData.dataWithBytes_length_(_lib, ptr.cast<Void>(), length);

      final envelope =
          cocoa.PrivateSentrySDKOnly.envelopeWithData_(_lib, nsData);

      cocoa.PrivateSentrySDKOnly.captureEnvelope_(_lib, envelope);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      malloc.free(ptr);
    }
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
