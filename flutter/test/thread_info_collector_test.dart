@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/thread_info_collector.dart';
import 'package:sentry_flutter/src/isolate_helper.dart';
import 'package:sentry/src/span_data_convention.dart';
import 'package:sentry/src/protocol/sentry_span.dart';
import 'package:sentry/src/sentry_span_context.dart';

void main() {
  late _Fixture fixture;

  setUp(() {
    fixture = _Fixture();
  });

  group('ThreadInfoCollector', () {
    test('sets main thread name when in root isolate', () async {
      fixture.mockHelper.setIsRootIsolate(true);
      fixture.mockHelper.setIsolateName("main(debug)");

      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);

      final setDataCalls = span.setDataCalls;
      expect(setDataCalls.length, equals(2));

      final threadIdCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadId);
      final threadNameCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadName);

      expect(threadIdCall.value, equals('main'.hashCode.toString()));
      expect(threadNameCall.value, equals('main'));
    });

    test('adds thread information when isolate has name', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('worker-thread');

      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);

      final setDataCalls = span.setDataCalls;
      expect(setDataCalls.length, equals(2));

      final threadIdCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadId);
      final threadNameCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadName);

      expect(threadIdCall.value, equals('worker-thread'.hashCode.toString()));
      expect(threadNameCall.value, equals('worker-thread'));
    });

    test('onSpanFinished is no-op', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanFinished(span, DateTime.now());
      expect(span.setDataCalls, isEmpty);
    });

    test('gets thread info dynamically for each span', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('dynamic-test');

      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);
      final firstCallCount = span.setDataCalls.length;

      final span2 = fixture.createMockSpan();
      await collector.onSpanStarted(span2);

      // Should have same number of calls for both spans (thread info collected fresh each time)
      expect(span2.setDataCalls.length, equals(firstCallCount));

      // Both spans should have thread info when isolate has a name
      expect(firstCallCount, equals(2));
    });

    test('uses provided isolate name correctly', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('custom-isolate-name');
      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);

      // Find thread data calls
      String? threadId;
      String? threadName;
      for (final call in span.setDataCalls) {
        if (call.key == SpanDataConvention.threadId) {
          threadId = call.value as String?;
        }
        if (call.key == SpanDataConvention.threadName) {
          threadName = call.value as String?;
        }
      }

      expect(threadName, equals('custom-isolate-name'));
      expect(threadId, equals('custom-isolate-name'.hashCode.toString()));
    });

    test('no thread info when isolate name is null', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName(null);
      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);

      // When isolate name is null, no thread data should be set
      expect(span.setDataCalls, isEmpty);
    });

    test('no thread info when isolate name is empty', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('');
      final collector = fixture.getSut();
      final span = fixture.createMockSpan();

      await collector.onSpanStarted(span);

      // When isolate name is empty, no thread data should be set
      expect(span.setDataCalls, isEmpty);
    });
  });
}

class _Fixture {
  late _MockIsolateHelper mockHelper;

  _Fixture() {
    mockHelper = _MockIsolateHelper();
    // Set default return values to avoid null errors
    mockHelper.setIsRootIsolate(false);
    mockHelper.setIsolateName(null);
  }

  ThreadInfoCollector getSut() {
    return ThreadInfoCollector(mockHelper);
  }

  _MockSpan createMockSpan() {
    return _MockSpan();
  }
}

class _MockIsolateHelper extends Mock implements IsolateHelper {
  bool _isRootIsolate = false;
  String? _isolateName;

  @override
  bool isRootIsolate() => _isRootIsolate;

  @override
  String? getIsolateName() => _isolateName;

  void setIsRootIsolate(bool value) => _isRootIsolate = value;
  void setIsolateName(String? value) => _isolateName = value;
}

class _MockSpan extends Mock implements SentrySpan {
  final SentrySpanContext _context = SentrySpanContext(operation: 'test');
  final List<_SetDataCall> setDataCalls = [];

  @override
  SentrySpanContext get context => _context;

  @override
  void setData(String key, dynamic value) {
    setDataCalls.add(_SetDataCall(key, value));
  }
}

class _SetDataCall {
  final String key;
  final dynamic value;

  _SetDataCall(this.key, this.value);
}
