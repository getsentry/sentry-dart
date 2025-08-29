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
      final dependencyContainer =
          cocoa.SentryDependencyContainer.sharedInstance();

      // Extract unique image addresses from stack trace
      final imageAddresses = stackTrace.frames
          .where((frame) => frame.instructionAddr != null)
          .map((frame) => frame.instructionAddr!)
          .map((addr) => int.tryParse(addr.replaceFirst('0x', ''), radix: 16))
          .whereType<int>()
          .map((addr) =>
              dependencyContainer.binaryImageCache.imageByAddress(addr))
          .whereType<cocoa.SentryBinaryImageInfo>()
          .map((image) => '0x${image.address.toRadixString(16)}')
          .toSet();

      List<DebugImage> debugImages = [];

      if (imageAddresses.isNotEmpty) {
        // Get debug images for specific addresses
        final nsSet = NSMutableSet();
        imageAddresses.forEach((addr) => nsSet.addObject(NSString(addr)));
        debugImages = _convertDebugImages(_castToSentryDebugMetaList(
            dependencyContainer.debugImageProvider
                .getDebugImagesForImageAddressesFromCache(nsSet)));
      }

      // Return debug images referenced by stack trace addresses
      // otherwise if none found, all debug images are returned.
      return debugImages.isEmpty
          ? _convertDebugImages(_castToSentryDebugMetaList(
              cocoa.PrivateSentrySDKOnly.getDebugImages()))
          : debugImages;
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
  Future<Map<String, dynamic>?> loadContexts() async {
    Map<String, dynamic>? result;

    cocoa.SentrySDK.configureScope(
        cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction((scope) {
      final serializedScope = scope.serialize();
      final serialized = toDartObject(serializedScope);
      print('serialized is Map: ${serialized is Map}');
    }));
    //     final scopeDict = _nsObjectToMap(serializedScope);
    //
    //     // Initialize context map
    //     Map<String, dynamic> context = {};
    //     if (scopeDict['context'] is Map<String, dynamic>) {
    //       context = Map<String, dynamic>.from(
    //           scopeDict['context'] as Map<String, dynamic>);
    //     }
    //
    //     // Initialize result map
    //     Map<String, dynamic> infos = {};
    //
    //     // Extract basic scope data
    //     if (scopeDict['tags'] != null) infos['tags'] = scopeDict['tags'];
    //     if (scopeDict['extra'] != null) infos['extra'] = scopeDict['extra'];
    //     if (scopeDict['dist'] != null) infos['dist'] = scopeDict['dist'];
    //     if (scopeDict['environment'] != null)
    //       infos['environment'] = scopeDict['environment'];
    //     if (scopeDict['fingerprint'] != null)
    //       infos['fingerprint'] = scopeDict['fingerprint'];
    //     if (scopeDict['level'] != null) infos['level'] = scopeDict['level'];
    //     if (scopeDict['breadcrumbs'] != null)
    //       infos['breadcrumbs'] = scopeDict['breadcrumbs'];
    //
    //     // Handle user data
    //     if (scopeDict['user'] != null) {
    //       infos['user'] = scopeDict['user'];
    //     } else {
    //       final installationId = cocoa.PrivateSentrySDKOnly.getInstallationID();
    //       infos['user'] = {'id': installationId.toString()};
    //     }
    //
    //     // Get integrations from options
    //     try {
    //       final options = cocoa.PrivateSentrySDKOnly.getOptions();
    //       // Note: We would need to access options.integrations here, but the binding might not expose it
    //       // For now, we'll skip this part as it requires accessing specific properties of SentryOptions
    //     } catch (e) {
    //       // Skip if options access fails
    //     }
    //
    //     // Merge extra context from PrivateSentrySDKOnly
    //     try {
    //       final extraContext = cocoa.PrivateSentrySDKOnly.getExtraContext();
    //       final extraContextDict = _nsObjectToMap(extraContext);
    //
    //       // Merge device context
    //       if (extraContextDict['device'] is Map<String, dynamic>) {
    //         final extraDevice =
    //             extraContextDict['device'] as Map<String, dynamic>;
    //         if (context['device'] is Map<String, dynamic>) {
    //           final currentDevice = Map<String, dynamic>.from(
    //               context['device'] as Map<String, dynamic>);
    //           currentDevice.addAll(extraDevice);
    //           context['device'] = currentDevice;
    //         } else {
    //           context['device'] = extraDevice;
    //         }
    //       }
    //
    //       // Merge app context
    //       if (extraContextDict['app'] is Map<String, dynamic>) {
    //         final extraApp = extraContextDict['app'] as Map<String, dynamic>;
    //         if (context['app'] is Map<String, dynamic>) {
    //           final currentApp = Map<String, dynamic>.from(
    //               context['app'] as Map<String, dynamic>);
    //           currentApp.addAll(extraApp);
    //           context['app'] = currentApp;
    //         } else {
    //           context['app'] = extraApp;
    //         }
    //       }
    //     } catch (e) {
    //       // Skip if extra context access fails
    //     }
    //
    //     infos['contexts'] = context;
    //
    //     // Add package info
    //     try {
    //       final sdkVersion = cocoa.PrivateSentrySDKOnly.getSdkVersionString();
    //       infos['package'] = {
    //         'version': sdkVersion.toString(),
    //         'sdk_name': 'cocoapods:sentry-cocoa'
    //       };
    //     } catch (e) {
    //       // Skip if SDK version access fails
    //     }
    //
    //     result = infos;
    //   }),
    // );

    return result;
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

  /// Converts Cocoa/Foundation objects (NSDictionary/NSArray/NSString/NSNumber)
  /// or already-converted Dart collections/primitives into Dart-friendly types.
  ///
  /// Accepts any dynamic value to be resilient to partially-converted objects
  /// and recursively converts nested structures.
  dynamic _nsObjectToMap(dynamic obj) {
    if (obj == null) {
      return null;
    }

    // Handle objects already bridged to Dart types
    if (obj is Map) {
      final mapResult = <String, dynamic>{};
      obj.forEach((key, value) {
        final keyString = key is String ? key : key.toString();
        mapResult[keyString] = _nsObjectToMap(value);
      });
      return mapResult;
    }
    if (obj is List) {
      return obj.map((e) => _nsObjectToMap(e)).toList();
    }
    if (obj is String || obj is num || obj is bool) {
      return obj;
    }

    // Handle Objective-C objects
    if (obj is ObjCObjectBase) {
      // Fast-path checks for Foundation container subclasses
      if (obj is NSDictionary) {
        return _convertNSDictionaryToMap(obj);
      }
      // Treat NSMutableDictionary like NSDictionary via cast fallback
      try {
        final dict = NSDictionary.castFromPointer(obj.ref.pointer,
            retain: true, release: true);
        return _convertNSDictionaryToMap(dict);
      } catch (_) {}

      if (obj is NSArray) {
        final listResult = <dynamic>[];
        for (int i = 0; i < obj.length; i++) {
          listResult.add(_nsObjectToMap(obj[i]));
        }
        return listResult;
      }
      // Treat NSMutableArray like NSArray via cast fallback
      try {
        final array = NSArray.castFromPointer(obj.ref.pointer,
            retain: true, release: true);
        final listResult = <dynamic>[];
        for (int i = 0; i < array.length; i++) {
          final element = array[i];
          listResult.add(_nsObjectToMap(element));
        }
        return listResult;
      } catch (_) {}

      // NSArray handled above (via is NSArray / cast fallback)

      // NSString
      if (obj is NSString) {
        return obj.toDartString();
      }

      // NSNumber (try to preserve integer vs double; booleans are handled
      // by upstream if bridged as Dart bools already)
      if (obj is NSNumber) {
        final doubleValue = obj.doubleValue;
        final intValue = obj.intValue;
        return doubleValue == intValue.toDouble() ? intValue : doubleValue;
      }

      // NSNull -> null
      try {
        // If NSNull is available in the runtime, detect it via toString match
        // fallback without introducing a hard type dependency.
        final className = obj.runtimeType.toString();
        if (className.contains('NSNull')) {
          return null;
        }
      } catch (_) {}

      // Fallback: stringify unknown ObjC objects
      return obj.toString();
    }

    // Final fallback for any other Dart object
    return obj.toString();
  }

  Map<String, dynamic> _convertNSDictionaryToMap(NSDictionary dict) {
    final result = <String, dynamic>{};
    final keys = dict.allKeys;
    final values = dict.allValues;
    final count = keys.length < values.length ? keys.length : values.length;
    for (int i = 0; i < count; i++) {
      final key = keys[i];
      final value = values[i];
      final keyString = key is NSString ? key.toDartString() : key.toString();
      result[keyString] = _nsObjectToMap(value);
    }
    return result;
  }

  // Intentionally left out: unused helper for NSArray conversion
}
