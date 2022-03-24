import 'jvm_frame.dart';

const _emptyString = '';
const _causedBy = 'Caused by:';
const _suppressed = 'Suppressed:';
const _newLine = '\n';

class JvmException {
  JvmException({
    this.thread,
    this.type,
    this.description,
    required this.stackTrace,
    this.causes,
    this.suppressed,
  });

  factory JvmException.parse(String exception) {
    return _parse(exception);
  }

  static JvmException? tryParse(String exception) {
    try {
      return JvmException.parse(exception);
    } catch (_) {
      return null;
    }
  }

  final String? thread;
  final String? type;
  final String? description;

  final List<JvmFrame> stackTrace;

  final List<JvmException>? causes;
  final List<JvmException>? suppressed;

  static JvmException _parse(String string) {
    final lines = string.split(_newLine);
    final first = _parseFirstLine(lines.first);
    lines.removeAt(0);

    final thisException = <String>[];
    final causes = <List<String>>[];
    final supressed = <List<String>>[];

    var frames = thisException;
    for (final line in lines) {
      var trimmed = line.trim();

      if (trimmed.startsWith(_causedBy)) {
        trimmed = trimmed.replaceAll(_causedBy, _emptyString).trim();
        causes.add(<String>[]);
        frames = causes.last;
      } else if (trimmed.startsWith(_suppressed)) {
        trimmed = trimmed.replaceAll(_suppressed, _emptyString).trim();
        supressed.add(<String>[]);
        frames = supressed.last;
      }
      frames.add(trimmed);
    }

    final thisExceptionFrames =
        thisException.map((e) => JvmFrame.parse(e)).toList(growable: false);

    final suppressedExceptions = supressed
        .map((e) => JvmException.parse(e.join(_newLine)))
        .toList(growable: false);

    final causeExceptions = causes
        .map((e) => JvmException.parse(e.join(_newLine)))
        .toList(growable: false);

    return JvmException(
      thread: first[0],
      type: first[1],
      description: first[2],
      stackTrace: thisExceptionFrames,
      suppressed: suppressedExceptions.isEmpty ? null : suppressedExceptions,
      causes: causeExceptions.isEmpty ? null : causeExceptions,
    );
  }

  // first element is the thread
  // second element is the Exception type
  // thirs element is the exception description
  static List<String?> _parseFirstLine(String firstLine) {
    final list = <String?>[];
    // Exception in thread "main" java.lang.Exception: Main block
    firstLine = firstLine.trim();
    if (firstLine.startsWith('Exception in thread "')) {
      firstLine = firstLine.replaceFirst('Exception in thread "', '');
      final firstLineSplitted = firstLine.split('"');
      list.add(firstLineSplitted.first);
      firstLine = firstLineSplitted[1].trim();
    } else {
      list.add(null);
    }
    final firstLineSplitted = firstLine.split(': ');
    final type = firstLineSplitted.first;
    final description = firstLine.substring(type.length + 2).trim();
    list.add(type);
    list.add(description.isEmpty ? null : description);
    return list;
  }
}
