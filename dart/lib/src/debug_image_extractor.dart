import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../sentry.dart';

// Regular expressions for parsing header lines
const String _headerStartLine =
    '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***';
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
    if (_debugImage != null) {
      return _debugImage;
    }
    _debugImage = _extractDebugInfoFrom(stackTraceString).toDebugImage();
    return _debugImage;
  }

  _DebugInfo _extractDebugInfoFrom(String stackTraceString) {
    String? buildId;
    String? isolateDsoBase;

    final lines = stackTraceString.split('\n');

    for (final line in lines) {
      if (_isHeaderStartLine(line)) {
        continue;
      }
      // Stop parsing as soon as we get to the stack frames
      // This should never happen but is a safeguard to avoid looping
      // through every line of the stack trace
      if (line.contains("#00 abs")) {
        break;
      }

      buildId ??= _extractBuildId(line);
      isolateDsoBase ??= _extractIsolateDsoBase(line);

      // Early return if all needed information is found
      if (buildId != null && isolateDsoBase != null) {
        return _DebugInfo(buildId, isolateDsoBase, _options);
      }
    }

    return _DebugInfo(buildId, isolateDsoBase, _options);
  }

  bool _isHeaderStartLine(String line) {
    return line.contains(_headerStartLine);
  }

  String? _extractBuildId(String line) {
    final buildIdMatch = _buildIdRegex.firstMatch(line);
    return buildIdMatch?.group(1);
  }

  String? _extractIsolateDsoBase(String line) {
    final isolateMatch = _isolateDsoBaseLineRegex.firstMatch(line);
    return isolateMatch?.group(1);
  }
}

class _DebugInfo {
  final String? buildId;
  final String? isolateDsoBase;
  final SentryOptions _options;

  _DebugInfo(this.buildId, this.isolateDsoBase, this._options);

  DebugImage? toDebugImage() {
    if (buildId == null || isolateDsoBase == null) {
      _options.logger(SentryLevel.warning,
          'Cannot create DebugImage without buildId and isolateDsoBase.');
      return null;
    }

    String type;
    String? imageAddr;
    String? debugId;
    String? codeId;

    final platform = _options.platformChecker.platform;

    // Default values for all platforms
    imageAddr = '0x$isolateDsoBase';

    if (platform.isAndroid) {
      type = 'elf';
      debugId = _convertCodeIdToDebugId(buildId!);
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
      imageAddr: imageAddr,
      debugId: debugId,
      codeId: codeId,
    );
  }

  // Debug identifier is the little-endian UUID representation of the first 16-bytes of
  // the build ID on ELF images.
  String? _convertCodeIdToDebugId(String codeId) {
    codeId = codeId.replaceAll(' ', '');
    if (codeId.length < 32) {
      _options.logger(SentryLevel.warning,
          'Code ID must be at least 32 hexadecimal characters long');
      return null;
    }

    final first16Bytes = codeId.substring(0, 32);
    final byteData = _parseHexToBytes(first16Bytes);

    if (byteData == null || byteData.isEmpty) {
      _options.logger(
          SentryLevel.warning, 'Failed to convert code ID to debug ID');
      return null;
    }

    return bigToLittleEndianUuid(UuidValue.fromByteList(byteData).uuid);
  }

  Uint8List? _parseHexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      _options.logger(
          SentryLevel.warning, 'Invalid hex string during debug image parsing');
      return null;
    }
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }

    var bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  String bigToLittleEndianUuid(String bigEndianUuid) {
    final byteArray =
        Uuid.parse(bigEndianUuid, validationMode: ValidationMode.nonStrict);

    final reversedByteArray = Uint8List.fromList([
      ...byteArray.sublist(0, 4).reversed,
      ...byteArray.sublist(4, 6).reversed,
      ...byteArray.sublist(6, 8).reversed,
      ...byteArray.sublist(8, 10),
      ...byteArray.sublist(10),
    ]);

    return Uuid.unparse(reversedByteArray);
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
