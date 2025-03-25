import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryStackFrame = SentryStackFrame(
    absPath: 'absPath',
    fileName: 'fileName',
    function: 'function',
    module: 'module',
    lineNo: 1,
    colNo: 2,
    contextLine: 'contextLine',
    inApp: true,
    package: 'package',
    native: false,
    platform: 'platform',
    imageAddr: 'imageAddr',
    symbolAddr: 'symbolAddr',
    instructionAddr: 'instructionAddr',
    rawFunction: 'rawFunction',
    framesOmitted: [1],
    preContext: ['a'],
    postContext: ['b'],
    vars: {'key': 'value'},
    unknown: testUnknown,
  );

  final sentryStackFrameJson = <String, dynamic>{
    'pre_context': ['a'],
    'post_context': ['b'],
    'vars': {'key': 'value'},
    'frames_omitted': [1],
    'filename': 'fileName',
    'package': 'package',
    'function': 'function',
    'module': 'module',
    'lineno': 1,
    'colno': 2,
    'abs_path': 'absPath',
    'context_line': 'contextLine',
    'in_app': true,
    'native': false,
    'platform': 'platform',
    'image_addr': 'imageAddr',
    'symbol_addr': 'symbolAddr',
    'instruction_addr': 'instructionAddr',
    'raw_function': 'rawFunction',
  };
  sentryStackFrameJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryStackFrame.toJson();

      expect(
        DeepCollectionEquality().equals(sentryStackFrameJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryStackFrame = SentryStackFrame.fromJson(sentryStackFrameJson);
      final json = sentryStackFrame.toJson();

      expect(
        DeepCollectionEquality().equals(sentryStackFrameJson, json),
        true,
      );
    });
  });
}
