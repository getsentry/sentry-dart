import 'dart:async';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import '../utils/utf8_json.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';
import 'cocoa_envelope_sender.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  CocoaReplayRecorder? _replayRecorder;
  CocoaEnvelopeSender? _envelopeSender;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  SentryId? get replayId => _replayId;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??= CocoaReplayRecorder(options);

            final replayIdArg = call.arguments['replayId'];
            final replayIsBuffering =
                call.arguments['replayIsBuffering'] as bool? ?? false;

            final replayId = replayIdArg == null
                ? null
                : SentryId.fromId(replayIdArg as String);

            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // Only set replay ID on scope if not buffering (active session mode)
                // ignore: invalid_use_of_internal_member
                s.replayId = !replayIsBuffering ? replayId : null;
              });
            }

            return _replayRecorder!.captureScreenshot();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    _envelopeSender = CocoaEnvelopeSender(options);
    await _envelopeSender?.start();

    return super.init(hub);
  }

  @override
  FutureOr<SentryId> captureReplay() async {
    final replayId = await super.captureReplay();
    _replayId = replayId;
    return replayId;
  }

  Future<void> close() async {
    await _envelopeSender?.close();
    return super.close();
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _envelopeSender?.captureEnvelope(envelopeData);
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    try {
      final instructionAddressSet = stackTrace.frames
          .map((frame) => frame.instructionAddr)
          .nonNulls
          .toSet()
          .toNSSet();

      // Use a single FFI call to get images as UTF-8 encoded JSON instead of
      // making multiple FFI calls to convert each object individually. This approach
      // is significantly faster because images can be large.
      // Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting FFI objects to Dart objects one by one.

      // NOTE: when instructionAddressSet is empty, loadDebugImagesAsBytes will return
      // all debug images as fallback.
      final imagesUtf8JsonBytes =
          cocoa.SentryFlutterPlugin.loadDebugImagesAsBytes(
              instructionAddressSet);
      if (imagesUtf8JsonBytes == null) return null;

      final debugImageMaps =
          decodeUtf8JsonListOfMaps(imagesUtf8JsonBytes.toList());
      return debugImageMaps.map(DebugImage.fromJson).toList(growable: false);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load debug images',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    try {
      // Use a single FFI call to get contexts as UTF-8 encoded JSON instead of
      // making multiple FFI calls to convert each object individually. This approach
      // is significantly faster because contexts can be large and contain many nested
      // objects. Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting FFI objects to Dart objects one by one.
      final contextsUtf8JsonBytes =
          cocoa.SentryFlutterPlugin.loadContextsAsBytes();
      if (contextsUtf8JsonBytes == null) return null;

      final contexts = decodeUtf8JsonMap(contextsUtf8JsonBytes.toList());
      return contexts;
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load contexts',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
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
