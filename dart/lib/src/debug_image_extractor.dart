import 'dart:typed_data';
import 'package:meta/meta.dart';

import '../sentry.dart';

// Regular expressions for parsing header lines
const String _headerStartLine =
    '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***';
final RegExp _buildIdRegex = RegExp(r"build_id(?:=|: )'([\da-f]+)'");
final RegExp _isolateDsoBaseLineRegex =
    RegExp(r'isolate_dso_base(?:=|: )([\da-f]+)');

/// Processes a stack trace by extracting debug information from its header.
@internal
class DebugImageExtractor {
  DebugImageExtractor(this._options);

  final SentryOptions _options;

  DebugImage? extractDebugImageFrom(String stackTraceString) {
    return _extractDebugInfoFrom(stackTraceString).toDebugImage();
  }

  _DebugInfo _extractDebugInfoFrom(String stackTraceString) {
    String? buildId;
    String? isolateDsoBase;

    final lines = stackTraceString.split('\n');

    for (final line in lines) {
      if (_isHeaderStartLine(line)) {
        continue;
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

    final type = _options.platformChecker.platform.isAndroid ? 'elf' : 'macho';
    final debugId = _options.platformChecker.platform.isAndroid
        ? _convertCodeIdToDebugId(buildId!)
        : _hexToUuid(buildId!);
    final codeId =
        _options.platformChecker.platform.isAndroid ? buildId! : null;

    return DebugImage(
      type: type,
      imageAddr: '0x$isolateDsoBase',
      debugId: debugId,
      codeId: codeId,
    );
  }

  // Debug identifier is the little-endian UUID representation of the first 16-bytes of
  // the build ID on Android
  String? _convertCodeIdToDebugId(String codeId) {
    codeId = codeId.replaceAll(' ', '');
    if (codeId.length < 32) {
      _options.logger(SentryLevel.warning,
          'Code ID must be at least 32 hexadecimal characters long');
      return null;
    }

    final first16Bytes = codeId.substring(0, 32);
    final byteData = Uint8List.fromList(List.generate(16,
        (i) => int.parse(first16Bytes.substring(i * 2, i * 2 + 2), radix: 16)));

    final buffer = byteData.buffer.asByteData();
    final timeLow = buffer.getUint32(0, Endian.little);
    final timeMid = buffer.getUint16(4, Endian.little);
    final timeHiAndVersion = buffer.getUint16(6, Endian.little);
    final clockSeqHiAndReserved = buffer.getUint8(8);
    final clockSeqLow = buffer.getUint8(9);

    return [
      timeLow.toRadixString(16).padLeft(8, '0'),
      timeMid.toRadixString(16).padLeft(4, '0'),
      timeHiAndVersion.toRadixString(16).padLeft(4, '0'),
      clockSeqHiAndReserved.toRadixString(16).padLeft(2, '0') +
          clockSeqLow.toRadixString(16).padLeft(2, '0'),
      byteData
          .sublist(10)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
    ].join('-');
  }

  String? _hexToUuid(String hex) {
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
