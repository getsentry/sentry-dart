import 'dart:async';
import 'dart:typed_data';
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
    try {
      final nsData = envelopeData.toNSData();
      final envelope = cocoa.PrivateSentrySDKOnly.envelopeWithData(nsData);
      if (envelope != null) {
        cocoa.PrivateSentrySDKOnly.captureEnvelope(envelope);
      } else {
        options.log(
            SentryLevel.error, 'Failed to capture envelope: envelope is null');
      }
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    try {
      List<DebugImage> dartDebugImages = [];
      Set<String> imageAddresses = <String>{};

      final dependencyContainer =
          cocoa.SentryDependencyContainer.sharedInstance();
      final binaryImageCache = dependencyContainer.binaryImageCache;

      final instructionAddresses = stackTrace.frames
          .where((frame) => frame.instructionAddr != null)
          .map((frame) => frame.instructionAddr!)
          .toSet();

      if (instructionAddresses.isNotEmpty) {
        for (final addressStr in instructionAddresses) {
          final hexDigits = addressStr.replaceFirst('0x', '');
          final instructionAddress = int.tryParse(hexDigits, radix: 16);
          if (instructionAddress != null) {
            final image = binaryImageCache.imageByAddress(instructionAddress);
            if (image != null) {
              final imageAddress = '0x${image.address.toRadixString(16)}';
              imageAddresses.add(imageAddress);
            }
          }
        }

        if (imageAddresses.isNotEmpty) {
          final nsSet = NSMutableSet();
          for (final addr in imageAddresses) {
            nsSet.addObject(NSString(addr));
          }
          final debugImagesArray = _castToSentryDebugMetaList(
              dependencyContainer.debugImageProvider
                  .getDebugImagesForImageAddressesFromCache(nsSet));
          dartDebugImages.addAll(_convertDebugImages(debugImagesArray));
        }
      }

      // If no debug images found, fall back to getting all debug images
      if (dartDebugImages.isEmpty) {
        final debugImagesArray = _castToSentryDebugMetaList(
            cocoa.PrivateSentrySDKOnly.getDebugImages());
        dartDebugImages.addAll(_convertDebugImages(debugImagesArray));
      }

      return dartDebugImages;
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to load debug images',
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

  /// Safely casts NSArray items to SentryDebugMeta list
  List<cocoa.SentryDebugMeta> _castToSentryDebugMetaList(NSArray nsArray) {
    final result = <cocoa.SentryDebugMeta>[];
    for (int i = 0; i < nsArray.length; i++) {
      final item = nsArray[i];
      try {
        final debugMeta = item is cocoa.SentryDebugMeta
            ? item
            : cocoa.SentryDebugMeta.castFrom(item);
        result.add(debugMeta);
      } catch (e) {
        // Skip items that can't be cast
        options.log(SentryLevel.debug,
            'Skipping debug image that cannot be cast to SentryDebugMeta: $e');
      }
    }
    return result;
  }

  /// Converts cocoa debug meta to [DebugImage]
  DebugImage? _convertSingleDebugImage(cocoa.SentryDebugMeta image) {
    try {
      return DebugImage(
        debugId: image.debugID?.toDartString() ?? image.uuid?.toDartString(),
        type: image.type?.toDartString() ?? 'macho',
        codeFile: image.codeFile?.toDartString() ?? image.name?.toDartString(),
        imageAddr: image.imageAddress?.toDartString(),
        imageVmAddr: image.imageVmAddress?.toDartString(),
        imageSize: image.imageSize?.intValue,
      );
    } catch (exception, stackTrace) {
      if (options.automatedTestMode) {
        rethrow;
      }
      options.log(SentryLevel.error, 'Failed to convert debug image',
          exception: exception, stackTrace: stackTrace);
      return null;
    }
  }

  /// Converts cocoa debug meta list to [DebugImage] list
  List<DebugImage> _convertDebugImages(
      List<cocoa.SentryDebugMeta> cocoaDebugImages) {
    return cocoaDebugImages
        .map(_convertSingleDebugImage)
        .whereType<DebugImage>()
        .toList();
  }
}
