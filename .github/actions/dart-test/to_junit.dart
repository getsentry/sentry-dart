import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    stdout.writeln('Usage: dart to_junit.dart --input <jsonl> --output <xml>');
    return;
  }

  final input = options.input;
  final output = options.output;
  if (input == null || output == null) {
    stderr.writeln('Both --input and --output are required.');
    exitCode = 64;
    return;
  }

  final converter = _JUnitConverter();
  await converter.read(File(input));
  await File(output).writeAsString(converter.toXml());
}

class _Options {
  _Options({this.input, this.output, this.showHelp = false});

  final String? input;
  final String? output;
  final bool showHelp;

  static _Options parse(List<String> arguments) {
    String? input;
    String? output;
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        case '--input':
        case '-i':
          input = _nextValue(arguments, ++index, argument);
        case '--output':
        case '-o':
          output = _nextValue(arguments, ++index, argument);
        default:
          if (argument.startsWith('--input=')) {
            input = argument.substring('--input='.length);
          } else if (argument.startsWith('--output=')) {
            output = argument.substring('--output='.length);
          } else {
            throw FormatException('Unknown argument: $argument');
          }
      }
    }

    return _Options(input: input, output: output, showHelp: showHelp);
  }

  static String _nextValue(
    List<String> arguments,
    int index,
    String argument,
  ) {
    if (index >= arguments.length) {
      throw FormatException('Missing value for $argument');
    }
    return arguments[index];
  }
}

class _JUnitConverter {
  final Map<int, _SuiteReport> _suites = {};
  final Map<int, _TestReport> _tests = {};

  Future<void> read(File input) async {
    final lines = input
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('{')) {
        continue;
      }
      final event = jsonDecode(line);
      if (event is Map<String, dynamic>) {
        _process(event);
      }
    }
  }

  String toXml() {
    _addSyntheticFailures();

    final suites = _suites.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final tests = suites.fold<int>(0, (sum, suite) => sum + suite.testsCount);
    final failures = suites.fold<int>(0, (sum, suite) => sum + suite.failures);
    final errors = suites.fold<int>(0, (sum, suite) => sum + suite.errors);
    final skipped = suites.fold<int>(0, (sum, suite) => sum + suite.skipped);
    final time = suites.fold<double>(0, (sum, suite) => sum + suite.time);

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<testsuites tests="$tests" failures="$failures" errors="$errors" '
        'skipped="$skipped" time="${_duration(time)}">',
      );

    for (final suite in suites) {
      _writeSuite(buffer, suite);
    }

    buffer.writeln('</testsuites>');
    return buffer.toString();
  }

  void _process(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'suite':
        final suite = event['suite'];
        if (suite is Map<String, dynamic>) {
          final id = suite['id'];
          if (id is int) {
            _suites[id] = _SuiteReport(
              id,
              path: suite['path'] as String?,
              platform: suite['platform'] as String?,
            );
          }
        }
        break;
      case 'testStart':
        final test = event['test'];
        if (test is Map<String, dynamic>) {
          _startTest(test, event['time']);
        }
        break;
      case 'testDone':
        final testId = event['testID'];
        if (testId is int) {
          _tests[testId]
            ?..finishTime = _asInt(event['time'])
            ..result = event['result'] as String?
            ..skipped = event['skipped'] == true;
        }
        break;
      case 'error':
        final testId = event['testID'];
        if (testId is int) {
          _tests[testId]?.errors.add(
                _TestError(
                  event['error']?.toString() ?? 'Test error',
                  stackTrace: event['stackTrace']?.toString(),
                  isFailure: event['isFailure'] == true,
                ),
              );
        }
        break;
    }
  }

  void _startTest(Map<String, dynamic> test, Object? eventTime) {
    final id = test['id'];
    final suiteId = test['suiteID'];
    if (id is! int || suiteId is! int) {
      return;
    }

    final report = _TestReport(
      id,
      suiteId: suiteId,
      name: test['name']?.toString() ?? 'test-$id',
      startTime: _asInt(eventTime),
      hidden: test['hidden'] == true,
    );
    _tests[id] = report;
    _suiteFor(suiteId).tests.add(report);
  }

  _SuiteReport _suiteFor(int suiteId) {
    return _suites.putIfAbsent(suiteId, () => _SuiteReport(suiteId));
  }

  void _addSyntheticFailures() {
    for (final test in _tests.values) {
      if (test.isSkipped || test.errors.isNotEmpty) {
        continue;
      }
      if (test.result == 'failure' || test.result == 'error') {
        test.errors.add(
          _TestError('Test finished with result: ${test.result}'),
        );
      }
    }
  }

  void _writeSuite(StringBuffer buffer, _SuiteReport suite) {
    buffer.writeln(
      '  <testsuite name="${_xmlEscape(suite.name)}" '
      'tests="${suite.testsCount}" failures="${suite.failures}" '
      'errors="${suite.errors}" skipped="${suite.skipped}" '
      'time="${_duration(suite.time)}">',
    );

    final tests = suite.visibleTests.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final test in tests) {
      _writeTestCase(buffer, suite, test);
    }

    buffer.writeln('  </testsuite>');
  }

  void _writeTestCase(
    StringBuffer buffer,
    _SuiteReport suite,
    _TestReport test,
  ) {
    buffer.writeln(
      '    <testcase classname="${_xmlEscape(suite.className)}" '
      'name="${_xmlEscape(test.name)}" time="${_duration(test.time)}">',
    );

    if (test.isSkipped) {
      buffer.writeln('      <skipped/>');
    } else {
      for (final error in test.errors) {
        final tag = error.isFailure ? 'failure' : 'error';
        final message = _xmlEscape(error.message);
        buffer.writeln('      <$tag message="$message">');
        buffer.writeln(_indent(_xmlEscape(error.details), 8));
        buffer.writeln('      </$tag>');
      }
    }

    buffer.writeln('    </testcase>');
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }
}

class _SuiteReport {
  _SuiteReport(this.id, {String? path, String? platform})
      : name = path ?? platform ?? 'suite-$id',
        className = path ?? 'suite-$id';

  final int id;
  final String name;
  final String className;
  final List<_TestReport> tests = [];

  Iterable<_TestReport> get visibleTests => tests.where((test) => !test.hidden);

  int get testsCount => visibleTests.length;

  int get failures => visibleTests
      .where((test) => !test.isSkipped && test.errors.any((e) => e.isFailure))
      .length;

  int get errors => visibleTests
      .where((test) => !test.isSkipped && test.errors.any((e) => !e.isFailure))
      .length;

  int get skipped => visibleTests.where((test) => test.isSkipped).length;

  double get time =>
      visibleTests.fold<double>(0, (sum, test) => sum + test.time);
}

class _TestReport {
  _TestReport(
    this.id, {
    required this.suiteId,
    required this.name,
    required this.startTime,
    required this.hidden,
  });

  final int id;
  final int suiteId;
  final String name;
  final int? startTime;
  final bool hidden;
  final List<_TestError> errors = [];

  int? finishTime;
  String? result;
  bool skipped = false;

  bool get isSkipped => skipped || result == 'skipped';

  double get time {
    final start = startTime;
    final finish = finishTime;
    if (start == null || finish == null || finish < start) {
      return 0;
    }
    return (finish - start) / 1000;
  }
}

class _TestError {
  _TestError(this.message, {this.stackTrace, this.isFailure = true});

  final String message;
  final String? stackTrace;
  final bool isFailure;

  String get details {
    final stackTrace = this.stackTrace;
    if (stackTrace == null || stackTrace.isEmpty) {
      return message;
    }
    return '$message\n$stackTrace';
  }
}

String _duration(double seconds) => seconds.toStringAsFixed(3);

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _indent(String value, int spaces) {
  final indent = ' ' * spaces;
  return value.split('\n').map((line) => '$indent$line').join('\n');
}
