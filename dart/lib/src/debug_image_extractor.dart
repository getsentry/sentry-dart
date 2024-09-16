import 'dart:typed_data';
import 'package:meta/meta.dart';

import '../sentry.dart';

// Regular expressions for parsing header lines
final RegExp _buildIdRegex = RegExp(r"build_id(?:=|: )'([\da-f]+)'");
final RegExp _isolateDsoBaseLineRegex =
    RegExp(r'isolate_dso_base(?:=|: )([\da-f]+)');

/// Extracts debug information from stack trace header.
/// Needed for symbolication of Dart stack traces without native debug images.
@internal
class DebugImageExtractor {
  DebugImageExtractor(this._options);

  final SentryOptions _options;

  // We don't need to always parse the debug image, so we cache it here.
  DebugImage? _debugImage;

  @visibleForTesting
  DebugImage? get debugImageForTesting => _debugImage;

  DebugImage? extractFrom(String stackTraceString) {
    _debugImage ??= _extractDebugInfoFrom(stackTraceString).toDebugImage();
    return _debugImage;
  }

  _DebugInfo _extractDebugInfoFrom(String stackTraceString) {
    final buildId = _buildIdRegex.firstMatch(stackTraceString)?.group(1);
    final imageAddr =
        _isolateDsoBaseLineRegex.firstMatch(stackTraceString)?.group(1);

    return _DebugInfo(buildId, imageAddr, _options);
  }
}

class _DebugInfo {
  final String? buildId;
  final String? imageAddr;
  final SentryOptions _options;

  _DebugInfo(this.buildId, this.imageAddr, this._options);

  DebugImage? toDebugImage() {
    if (buildId == null || imageAddr == null) {
      _options.logger(SentryLevel.warning,
          'Cannot create DebugImage without buildId and isolateDsoBase.');
      return null;
    }

    String type;
    String? debugId;
    String? codeId;

    final platform = _options.platformChecker.platform;

    if (platform.isAndroid) {
      type = 'elf';
      debugId = _convertBuildIdToDebugId(buildId!);
      codeId = buildId;
    } else if (platform.isIOS || platform.isMacOS) {
      type = 'macho';
      debugId = _formatHexToUuid(buildId!);
      // `codeId` is not needed for iOS/MacOS.
    } else {
      _options.logger(
        SentryLevel.warning,
        'Unsupported platform for creating Dart debug images.',
      );
      return null;
    }

    return DebugImage(
      type: type,
      imageAddr: '0x$imageAddr',
      debugId: debugId,
      codeId: codeId,
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
  String? _convertBuildIdToDebugId(String buildId) {
    // Make sure that we have exactly UUID_SIZE bytes available
    const uuidSize = 16 * 2;
    final data = Uint8List(uuidSize);
    final len = buildId.length.clamp(0, uuidSize);
    data.setAll(0, buildId.codeUnits.take(len));

    if (Endian.host == Endian.little) {
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

  String? _formatHexToUuid(String hex) {
    if (hex.length != 32) {
      _options.logger(SentryLevel.warning,
          'Hex input must be a 32-character hexadecimal string');
      return null;
    }

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
