@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/integrations/thread_info_integration.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_helper.dart';

import '../mocks.mocks.dart';

void main() {
  late _Fixture fixture;

  setUp(() {
    fixture = _Fixture();
  });

  group('ThreadInfoIntegration', () {
    test('sets main thread name when in root isolate', () async {
      fixture.mockHelper.setIsRootIsolate(true);
      fixture.mockHelper.setIsolateName("main(debug)");

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      // Call the integration like the real app would
      integration.call(hub, fixture.options);

      // Dispatch OnSpanStart event through the lifecycle registry
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

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

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

      final setDataCalls = span.setDataCalls;
      expect(setDataCalls.length, equals(2));

      final threadIdCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadId);
      final threadNameCall = setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadName);

      expect(threadIdCall.value, equals('worker-thread'.hashCode.toString()));
      expect(threadNameCall.value, equals('worker-thread'));
    });

    test('gets thread info dynamically for each span', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('dynamic-test');

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));
      final firstCallCount = span.setDataCalls.length;

      final span2 = fixture.createMockSpan();
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span2));

      // Should have same number of calls for both spans (thread info collected fresh each time)
      expect(span2.setDataCalls.length, equals(firstCallCount));
    });

    test('sets thread ID and name for non-root isolate with valid name',
        () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('custom-isolate');

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

      // Find thread data calls
      final threadIdCall = span.setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadId);
      final threadNameCall = span.setDataCalls
          .firstWhere((call) => call.key == SpanDataConvention.threadName);

      expect(threadIdCall.value, equals('custom-isolate'.hashCode.toString()));
      expect(threadNameCall.value, equals('custom-isolate'));
    });

    test('does not set thread info when isolate name is null', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName(null);

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

      // When isolate name is null, no thread data should be set
      expect(span.setDataCalls, isEmpty);
    });

    test('does not set thread info when isolate name is empty', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName('');

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

      // When isolate name is empty, no thread data should be set
      expect(span.setDataCalls, isEmpty);
    });

    test('does not register callback when tracing is disabled', () async {
      fixture.mockHelper.setIsRootIsolate(true);
      fixture.mockHelper.setIsolateName("main");

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      // Disable tracing
      fixture.options.tracesSampleRate = null;

      integration.call(hub, fixture.options);
      // ignore: invalid_use_of_internal_member
      await fixture.options.lifecycleRegistry
          .dispatchCallback(OnSpanStart(span));

      // Should not add any thread data when tracing is disabled
      expect(span.setDataCalls, isEmpty);
    });
  });
}

class _Fixture {
  late _MockIsolateHelper mockHelper;
  late SentryFlutterOptions options;

  _Fixture() {
    mockHelper = _MockIsolateHelper();
    options = SentryFlutterOptions();
    options.tracesSampleRate = 1.0; // Enable tracing by default
    // Set default return values to avoid null errors
    mockHelper.setIsRootIsolate(false);
    mockHelper.setIsolateName(null);
  }

  ThreadInfoIntegration getSut() {
    return ThreadInfoIntegration(mockHelper);
  }

  _MockSpan createMockSpan() {
    return _MockSpan();
  }

  MockHub createHub() {
    final hub = MockHub();
    when(hub.options).thenReturn(options);
    return hub;
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
