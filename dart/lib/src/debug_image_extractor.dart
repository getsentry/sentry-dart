import 'dart:typed_data';
import 'package:meta/meta.dart';

import '../sentry.dart';

// Regular expressions for parsing header lines
const String _headerStartLine =
    '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***';
final RegExp _osArchLineRegex = RegExp(
    r'os(?:=|: )(\S+?),? arch(?:=|: )(\S+?),? comp(?:=|: )(yes|no),? sim(?:=|: )(yes|no)');
final RegExp _buildIdRegex = RegExp(r"build_id(?:=|: )'([\da-f]+)'");
final RegExp _isolateDsoBaseLineRegex =
    RegExp(r'isolate_dso_base(?:=|: )([\da-f]+)');

@immutable
@internal
class DebugInfo {
  final String? arch;
  final String? buildId;
  final String? isolateDsoBase;
  final SentryOptions options;

  DebugInfo(this.arch, this.buildId, this.isolateDsoBase, this.options);

  DebugImage? toDebugImage() {
    if (buildId == null || isolateDsoBase == null) {
      // TODO: log
      return null;
    }

    final type = options.platformChecker.platform.isAndroid ? 'elf' : 'macho';
    final debugId = options.platformChecker.platform.isAndroid
        ? _convertCodeIdToDebugId(buildId!)
        : _hexToUuid(buildId!);
    final codeId = options.platformChecker.platform.isAndroid ? buildId! : null;

    return DebugImage(
      type: type,
      imageAddr: '0x$isolateDsoBase',
      debugId: debugId,
      codeId: codeId,
      arch: arch,
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

/// Processes a stack trace by extracting debug image information from it and
/// creating a synthetic representation of a debug image.
/// Currently working for iOS, macOS and Android.
@internal
class DebugImageExtractor {
  DebugImageExtractor(this._options);

  final SentryOptions _options;

  DebugInfo extractFrom(StackTrace stackTrace) {
    String? arch;
    String? buildId;
    String? isolateDsoBase;

    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      if (line.contains(_headerStartLine)) {
        arch = buildId = isolateDsoBase = null;
        continue;
      }

      final archMatch = _osArchLineRegex.firstMatch(line);
      if (archMatch != null) {
        arch = archMatch[2];
        continue;
      }

      final buildIdMatch = _buildIdRegex.firstMatch(line);
      if (buildIdMatch != null) {
        buildId = buildIdMatch[1];
        continue;
      }

      final isolateMatch = _isolateDsoBaseLineRegex.firstMatch(line);
      if (isolateMatch != null) {
        isolateDsoBase = isolateMatch[1];
        continue;
      }
    }

    return DebugInfo(arch, buildId, isolateDsoBase, _options);
  }
}
