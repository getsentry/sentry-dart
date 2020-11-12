import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('should serialize stacktrace', () {
    final mechanism = Mechanism(
      type: 'mechanism-example',
      description: 'a mechanism',
      handled: true,
      synthetic: false,
      helpLink: 'https://help.com',
      data: {'polyfill': 'bluebird'},
      meta: {
        'signal': {
          'number': 10,
          'code': 0,
          'name': 'SIGBUS',
          'code_name': 'BUS_NOOP'
        }
      },
    );
    final stacktrace = SentryStackTrace(frames: [
      SentryStackFrame(
        absPath: 'frame-path',
        fileName: 'example.dart',
        function: 'parse',
        module: 'example-module',
        lineNo: 1,
        colNo: 2,
        contextLine: 'context-line example',
        inApp: true,
        package: 'example-package',
        native: false,
        platform: 'dart',
        rawFunction: 'example-rawFunction',
        framesOmitted: [1, 2, 3],
      ),
    ]);

    final sentryException = SentryException(
      type: 'StateError',
      value: 'Bad state: error',
      module: 'example.module',
      stackTrace: stacktrace,
      mechanism: mechanism,
      threadId: 123456,
    );

    final serialized = sentryException.toJson();

    expect(serialized['type'], 'StateError');
    expect(serialized['value'], 'Bad state: error');
    expect(serialized['module'], 'example.module');
    expect(serialized['thread_id'], 123456);
    expect(serialized['mechanism']['type'], 'mechanism-example');
    expect(serialized['mechanism']['description'], 'a mechanism');
    expect(serialized['mechanism']['handled'], true);
    expect(serialized['mechanism']['synthetic'], false);
    expect(serialized['mechanism']['help_link'], 'https://help.com');
    expect(serialized['mechanism']['data'], {'polyfill': 'bluebird'});
    expect(serialized['mechanism']['meta'], {
      'signal': {
        'number': 10,
        'code': 0,
        'name': 'SIGBUS',
        'code_name': 'BUS_NOOP'
      }
    });

    final serializedFrame = serialized['stacktrace']['frames'].first;
    expect(serializedFrame['abs_path'], 'frame-path');
    expect(serializedFrame['filename'], 'example.dart');
    expect(serializedFrame['function'], 'parse');
    expect(serializedFrame['module'], 'example-module');
    expect(serializedFrame['lineno'], 1);
    expect(serializedFrame['colno'], 2);
    expect(serializedFrame['context_line'], 'context-line example');
    expect(serializedFrame['in_app'], true);
    expect(serializedFrame['package'], 'example-package');
    expect(serializedFrame['native'], false);
    expect(serializedFrame['platform'], 'dart');
    expect(serializedFrame['raw_function'], 'example-rawFunction');
    expect(serializedFrame['frames_omitted'], [1, 2, 3]);
  });
}
