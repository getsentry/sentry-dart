import 'dart:io';

void main() async {
  final result = await Process.run('dart', ['pub', 'publish', '--dry-run']);

  final output = result.stderr as String;

  if (output.contains('Found no `pubspec.yaml` file')) {
    print(output);
    exit(1);
  }

  final expectedErrors = [
    'lib/src/event_processor/enricher/web_enricher_event_processor.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/origin_web.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`',
    'lib/src/platform/_web_platform.dart: This package does not have web in the `dependencies` section of `pubspec.yaml`'
  ];

  final lines = output.split('\n').where((line) => line.startsWith('*')).toList();
  final unexpectedErrors = lines.where((line) {
    return !expectedErrors.any((expectedError) => line.contains(expectedError));
  }).toList();

  if (unexpectedErrors.isNotEmpty) {
    print('Unexpected errors found:');
    unexpectedErrors.forEach(print);
    exit(1);
  } else {
    print('Only expected errors found. Validation passed.');
    exit(0);
  }
}
