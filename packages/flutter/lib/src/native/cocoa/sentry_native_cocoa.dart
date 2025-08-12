import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
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

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    // Use a safe copy-based conversion to avoid crashes due to memory issues observed
    // when relying on `dataWithBytesNoCopy:length:freeWhenDone:`.
    final length = envelopeData.length;
    final buffer = malloc<Uint8>(length);
    cocoa.NSData? nsData;
    cocoa.SentryEnvelope? envelope;
    try {
      buffer.asTypedList(length).setAll(0, envelopeData);
      nsData = cocoa.NSData.dataWithBytes_length_(_lib, buffer.cast(), length);
      envelope = cocoa.PrivateSentrySDKOnly.envelopeWithData_(_lib, nsData);
      cocoa.PrivateSentrySDKOnly.captureEnvelope_(_lib, envelope);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      // Release ObjC wrappers promptly and free the temporary C buffer.
      if (envelope != null) {
        try {
          envelope.release();
        } catch (_) {}
      }
      if (nsData != null) {
        try {
          nsData.release();
        } catch (_) {}
      }
      malloc.free(buffer);
    }
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    // Note: unused on iOS.
  }

  @override
  int? startProfiler(SentryId traceId) => tryCatchSync(
        'startProfiler',
        () {
          final sentryId$1 = cocoa.SentryId$1.alloc()
              .initWithUUIDString(NSString(traceId.toString()));

          final sentryId = cocoa.SentryId.castFromPointer(
            sentryId$1.ref.pointer,
            retain: true,
            release: true,
          );

          final startTime =
              cocoa.PrivateSentrySDKOnly.startProfilerForTrace(sentryId);
          return startTime;
        },
      );
}
