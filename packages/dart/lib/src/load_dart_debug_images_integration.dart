import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'debug_logger.dart';
import 'event_processor.dart';
import 'hint.dart';
import 'hub.dart';
import 'integration.dart';
import 'protocol/debug_image.dart';
import 'protocol/debug_meta.dart';
import 'protocol/sentry_event.dart';
import 'protocol/sentry_level.dart';
import 'protocol/sentry_stack_trace.dart';
import 'sentry_options.dart';

class LoadDartDebugImagesIntegration extends Integration<SentryOptions> {
  static const integrationName = 'LoadDartDebugImages';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.enableDartSymbolication &&
        (options.runtimeChecker.isAppObfuscated() ||
            options.runtimeChecker.isSplitDebugInfoBuild()) &&
        !options.platform.isWeb) {
      options.addEventProcessor(
          LoadDartDebugImagesIntegrationEventProcessor(options));
      options.sdk.addIntegration(integrationName);
    }
  }
}

@internal
class LoadDartDebugImagesIntegrationEventProcessor implements EventProcessor {
  LoadDartDebugImagesIntegrationEventProcessor(this._options);

  final SentryOptions _options;

  // We don't need to always create the debug image, so we cache it here.
  DebugImage? _debugImage;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final stackTrace = event.stacktrace;
    if (stackTrace != null) {
      final debugImage = getAppDebugImage(stackTrace);
      if (debugImage != null) {
        if (event.debugMeta != null) {
          event.debugMeta?.addDebugImage(debugImage);
        } else {
          event.debugMeta = DebugMeta(images: [debugImage]);
        }
      }
    }

    return event;
  }

  DebugImage? getAppDebugImage(SentryStackTrace stackTrace) {
    // Don't return the debug image if the stack trace doesn't have native info.
    if (stackTrace.baseAddr == null ||
        stackTrace.buildId == null ||
        !stackTrace.frames.any((f) => f.platform == 'native')) {
      return null;
    }
    try {
      _debugImage ??= createDebugImage(stackTrace);
    } catch (e, stack) {
      debugLogger.warning(
          "Couldn't add Dart debug image to event. The event will still be reported.",
          error: e,
          stackTrace: stack,
          category: 'load_dart_debug_images');
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
    return _debugImage;
  }

  @visibleForTesting
  DebugImage? createDebugImage(SentryStackTrace stackTrace) {
    if (stackTrace.buildId == null || stackTrace.baseAddr == null) {
      debugLogger.warning(
          'Cannot create DebugImage without a build ID and image base address.');
      return null;
    }

    // Type and DebugID are required for proper symbolication
    late final String type;
    late final String debugId;

    // CodeFile is required so that the debug image shows up properly in the UI.
    // It doesn't need to exist and is not used for symbolication.
    late final String codeFile;

    final platform = _options.platform;

    if (platform.isAndroid || platform.isWindows) {
      type = 'elf';
      debugId = _convertBuildIdToDebugId(stackTrace.buildId!, Endian.host);
      if (platform.isAndroid) {
        codeFile = 'libapp.so';
      } else if (platform.isWindows) {
        codeFile = 'data/app.so';
      }
    } else if (platform.isIOS || platform.isMacOS) {
      type = 'macho';
      debugId = _formatHexToUuid(stackTrace.buildId!);
      codeFile = 'App.Framework/App';
    } else {
      debugLogger.warning(
          'Unsupported platform for creating Dart debug images.',
          category: 'load_dart_debug_images');
      return null;
    }

    return DebugImage(
      type: type,
      imageAddr: stackTrace.baseAddr,
      debugId: debugId,
      codeId: stackTrace.buildId,
      codeFile: codeFile,
    );
  }

  /// See https://github.com/getsentry/symbolic/blob/7dc28dd04c06626489c7536cfe8c7be8f5c48804/symbolic-debuginfo/src/elf.rs#L709-L734
  /// Converts an ELF object identifier into a `DebugId`.
  ///
  /// The identifier data is first truncated or extended to match 16 byte size of
  /// Uuids. If the data is declared in little endian, the first three Uuid fields
  /// are flipped to match the big endian expected by the breakpad processor.
  ///
  /// The `DebugId::appendix` field is always `0` for ELF.
  String _convertBuildIdToDebugId(String buildId, Endian endian) {
    // Make sure that we have exactly UUID_SIZE bytes available
    const uuidSize = 16 * 2;
    final data = Uint8List(uuidSize);
    final len = buildId.length.clamp(0, uuidSize);
    data.setAll(0, buildId.codeUnits.take(len));

    if (endian == Endian.little) {
      // The file ELF file targets a little endian architecture. Convert to
      // network byte order (big endian) to match the Breakpad processor's
      // expectations. For big endian object files, this is not needed.
      // To manipulate this as hex, we create an Uint16 view.
      final data16 = Uint16List.view(data.buffer);
      data16.setRange(0, 4, data16.sublist(0, 4).reversed);
      data16.setRange(4, 6, data16.sublist(4, 6).reversed);
      data16.setRange(6, 8, data16.sublist(6, 8).reversed);
    }
    return _formatHexToUuid(String.fromCharCodes(data));
  }

  String _formatHexToUuid(String hex) {
    if (hex.length == 36) {
      return hex;
    }
    if (hex.length != 32) {
      throw ArgumentError.value(hex, 'hexUUID',
          'Hex input must be a 32-character hexadecimal string');
    }

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
