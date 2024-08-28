import 'dart:typed_data';
import 'package:meta/meta.dart';

import '../sentry.dart';

/// Processes a stack trace and extracts debug image information from it and
/// creates a synthetic representation of the debug image.
/// Currently working for iOS, macOS and Android.
@internal
class DebugImageExtractor {
  final SentryOptions _options;

  // Header information
  String? _arch;
  String? _buildId;
  String? _isolateDsoBase;

  // Regular expressions for parsing header lines
  static const String _headerStartLine =
      '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***';
  static final RegExp _osArchLineRegex = RegExp(
      r'os(?:=|: )(\S+?),? arch(?:=|: )(\S+?),? comp(?:=|: )(yes|no),? sim(?:=|: )(yes|no)');
  static final RegExp _buildIdRegex = RegExp(r"build_id(?:=|: )'([\da-f]+)'");
  static final RegExp _isolateDsoBaseLineRegex =
      RegExp(r'isolate_dso_base(?:=|: )([\da-f]+)');

  DebugImageExtractor(this._options);

  DebugImage? toImage(StackTrace stackTrace) {
    _parseStackTrace(stackTrace);
    return _createDebugImage();
  }

  void _parseStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      if (_tryParseHeaderLine(line)) continue;
    }
  }

  bool _tryParseHeaderLine(String line) {
    if (line.contains(_headerStartLine)) {
      _arch = _buildId = _isolateDsoBase = null;
      return true;
    }

    final parsers = <bool Function(String)>[
      _parseOsArchLine,
      _parseBuildIdLine,
      _parseIsolateDsoBaseLine,
    ];

    return parsers.any((parser) => parser(line));
  }

  bool _parseOsArchLine(String line) {
    final match = _osArchLineRegex.firstMatch(line);
    if (match != null) {
      _arch = match[2];
      return true;
    }
    return false;
  }

  bool _parseBuildIdLine(String line) {
    final match = _buildIdRegex.firstMatch(line);
    if (match != null) {
      _buildId = match[1];
      return true;
    }
    return false;
  }

  bool _parseIsolateDsoBaseLine(String line) {
    final match = _isolateDsoBaseLineRegex.firstMatch(line);
    if (match != null) {
      _isolateDsoBase = match[1];
      return true;
    }
    return false;
  }

  DebugImage? _createDebugImage() {
    if (_buildId == null || _isolateDsoBase == null) {
      // TODO: log
      return null;
    }

    final type = _options.platformChecker.platform.isAndroid ? 'elf' : 'macho';
    final debugId = _options.platformChecker.platform.isAndroid
        ? _convertCodeIdToDebugId(_buildId!)
        : _hexToUuid(_buildId!);
    final codeId =
        _options.platformChecker.platform.isAndroid ? _buildId! : null;
    return DebugImage(
      type: type,
      imageAddr: '0x$_isolateDsoBase',
      debugId: debugId,
      codeId: codeId,
      arch: _arch,
    );
  }

  // Debug identifier is the little-endian UUID representation of the first 16-bytes of
  // the build ID on Android
  String _convertCodeIdToDebugId(String codeId) {
    codeId = codeId.replaceAll(' ', '');
    if (codeId.length < 32) {
      // todo: don't throw
      throw ArgumentError(
          'Code ID must be at least 32 hexadecimal characters long');
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

  String _hexToUuid(String hex) {
    if (hex.length != 32) {
      // todo: don't throw
      throw FormatException('Input must be a 32-character hexadecimal string');
    }

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
