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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryStackFrame;

      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });
    test('copyWith takes new values', () {
      final data = sentryStackFrame;

      final copy = data.copyWith(
        absPath: 'absPath1',
        fileName: 'fileName1',
        function: 'function1',
        module: 'module1',
        lineNo: 11,
        colNo: 22,
        contextLine: 'contextLine1',
        inApp: false,
        package: 'package1',
        native: true,
        platform: 'platform1',
        imageAddr: 'imageAddr1',
        symbolAddr: 'symbolAddr1',
        instructionAddr: 'instructionAddr1',
        rawFunction: 'rawFunction1',
        framesOmitted: [11],
        preContext: ['ab'],
        postContext: ['bb'],
        vars: {'key1': 'value1'},
      );

      expect('absPath1', copy.absPath);
      expect('fileName1', copy.fileName);
      expect('function1', copy.function);
      expect('module1', copy.module);
      expect(11, copy.lineNo);
      expect(22, copy.colNo);
      expect(false, copy.inApp);
      expect('package1', copy.package);
      expect(true, copy.native);
      expect('platform1', copy.platform);
      expect('imageAddr1', copy.imageAddr);
      expect('symbolAddr1', copy.symbolAddr);
      expect('instructionAddr1', copy.instructionAddr);
      expect('rawFunction1', copy.rawFunction);
      expect([11], copy.framesOmitted);
      expect(['ab'], copy.preContext);
      expect(['bb'], copy.postContext);
      expect({'key1': 'value1'}, copy.vars);
    });
  });
}
