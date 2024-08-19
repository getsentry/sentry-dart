import 'dart:io';

import 'package:args/args.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'executable',
      allowed: ['dart', 'flutter'],
      defaultsTo: 'dart',
      help: 'Specify the executable to use (dart or flutter)',
    );

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('Usage: dart script.dart [--executable <dart|flutter>]');
    exit(1);
  }

  final executable = args['executable'] as String;

  final result = await Process.run(executable, ['pub', 'publish', '--dry-run']);
  final publishOutput = result.stderr as String;

  if (publishOutput.contains('Found no `pubspec.yaml` file')) {
    print(publishOutput);
    exit(1);
  }

  const expectedErrors = [
    'lib/src/integrations/connectivity/web_connectivity_provider.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/event_processor/enricher/web_enricher_event_processor.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/origin_web.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/platform/_web_platform.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/event_processor/url_filter/web_url_filter_event_processor.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
  ];

  // So far the expected errors all start with `* line`
  final errorLines = publishOutput
      .split('\n')
      .where((line) => line.startsWith('* line'))
      .toList();

  final unexpectedErrors = errorLines.where((errorLine) {
    return !expectedErrors
        .any((expectedError) => errorLine.contains(expectedError));
  }).toList();

  if (unexpectedErrors.isEmpty) {
    print('Only expected errors found. Validation passed.');
    exit(0);
  } else {
    print('Unexpected errors found:');
    unexpectedErrors.forEach(print);
    exit(1);
  }
}
