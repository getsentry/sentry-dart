// ignore_for_file: invalid_use_of_internal_member, experimental_member_use
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/src/integrations/thread_info_integration.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_helper.dart';

import '../mocks.dart';
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
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );

      final setDataCalls = span.setDataCalls;
      expect(setDataCalls.length, equals(2));

      final threadIdCall = setDataCalls.firstWhere(
        (call) => call.key == SemanticAttributesConstants.threadId,
      );
      final threadNameCall = setDataCalls.firstWhere(
        (call) => call.key == SemanticAttributesConstants.threadName,
      );

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
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );

      final setDataCalls = span.setDataCalls;
      expect(setDataCalls.length, equals(2));

      final threadIdCall = setDataCalls.firstWhere(
        (call) => call.key == SemanticAttributesConstants.threadId,
      );
      final threadNameCall = setDataCalls.firstWhere(
        (call) => call.key == SemanticAttributesConstants.threadName,
      );

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
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );
      final firstCallCount = span.setDataCalls.length;

      final span2 = fixture.createMockSpan();
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span2),
      );

      // Should have same number of calls for both spans (thread info collected fresh each time)
      expect(span2.setDataCalls.length, equals(firstCallCount));
    });

    test(
      'sets thread ID and name for non-root isolate with valid name',
      () async {
        fixture.mockHelper.setIsRootIsolate(false);
        fixture.mockHelper.setIsolateName('custom-isolate');

        final hub = fixture.createHub();
        final integration = fixture.getSut();
        final span = fixture.createMockSpan();

        integration.call(hub, fixture.options);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanStart(span),
        );

        // Find thread data calls
        final threadIdCall = span.setDataCalls.firstWhere(
          (call) => call.key == SemanticAttributesConstants.threadId,
        );
        final threadNameCall = span.setDataCalls.firstWhere(
          (call) => call.key == SemanticAttributesConstants.threadName,
        );

        expect(
          threadIdCall.value,
          equals('custom-isolate'.hashCode.toString()),
        );
        expect(threadNameCall.value, equals('custom-isolate'));
      },
    );

    test('does not set thread info when isolate name is null', () async {
      fixture.mockHelper.setIsRootIsolate(false);
      fixture.mockHelper.setIsolateName(null);

      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpan();

      integration.call(hub, fixture.options);
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );

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
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );

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
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanStart(span),
      );

      // Should not add any thread data when tracing is disabled
      expect(span.setDataCalls, isEmpty);
    });
  });

  group('OnSpanFinish sync processing', () {
    test(
      'sets blocked_main_thread when sync span finishes on main isolate',
      () async {
        fixture.mockHelper.setIsRootIsolate(true);

        final hub = fixture.createHub();
        final integration = fixture.getSut();
        final span = fixture.createMockSpanWithData({
          'sync': true,
          SemanticAttributesConstants.threadName: 'main',
        });

        integration.call(hub, fixture.options);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanFinish(span),
        );

        final setDataCalls = span.setDataCalls;
        expect(setDataCalls.length, equals(1));

        final blockedMainThreadCall = setDataCalls.firstWhere(
          (call) => call.key == SemanticAttributesConstants.blockedMainThread,
        );
        expect(blockedMainThreadCall.value, equals(true));

        // Check that sync was removed
        expect(span.removeDataCalls.length, equals(1));
        expect(span.removeDataCalls.first.key, equals('sync'));
      },
    );

    test(
      'does not set blocked_main_thread when sync span finishes on background isolate',
      () async {
        final hub = fixture.createHub();
        final integration = fixture.getSut();
        final span = fixture.createMockSpanWithData({
          'sync': true,
          SemanticAttributesConstants.threadName: 'worker-thread',
        });

        integration.call(hub, fixture.options);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanFinish(span),
        );

        // Should not set blocked_main_thread
        final blockedMainThreadCalls = span.setDataCalls.where(
          (call) => call.key == SemanticAttributesConstants.blockedMainThread,
        );
        expect(blockedMainThreadCalls, isEmpty);

        // But should still remove sync
        expect(span.removeDataCalls.length, equals(1));
        expect(span.removeDataCalls.first.key, equals('sync'));
      },
    );

    test('does not process spans without sync data', () async {
      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpanWithData({
        SemanticAttributesConstants.threadName: 'main',
      });

      integration.call(hub, fixture.options);
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanFinish(span),
      );

      // Should not add any data or remove anything
      expect(span.setDataCalls, isEmpty);
      expect(span.removeDataCalls, isEmpty);
    });

    test('does not set blocked_main_thread when sync is false', () async {
      final hub = fixture.createHub();
      final integration = fixture.getSut();
      final span = fixture.createMockSpanWithData({
        'sync': false,
        SemanticAttributesConstants.threadName: 'main',
      });

      integration.call(hub, fixture.options);
      await fixture.options.lifecycleRegistry.dispatchCallback(
        OnSpanFinish(span),
      );

      // sync == false is not synchronous, so blocked_main_thread is not set.
      final blockedMainThreadCalls = span.setDataCalls.where(
        (call) => call.key == SemanticAttributesConstants.blockedMainThread,
      );
      expect(blockedMainThreadCalls, isEmpty);

      // But the internal marker is still stripped so it never leaks to Sentry.
      expect(span.removeDataCalls.map((call) => call.key), contains('sync'));
    });

    test(
      'does not set blocked_main_thread when sync span has no thread name',
      () async {
        final hub = fixture.createHub();
        final integration = fixture.getSut();
        final span = fixture.createMockSpanWithData({'sync': true});

        integration.call(hub, fixture.options);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanFinish(span),
        );

        // Should not set blocked_main_thread (no thread name)
        final blockedMainThreadCalls = span.setDataCalls.where(
          (call) => call.key == SemanticAttributesConstants.blockedMainThread,
        );
        expect(blockedMainThreadCalls, isEmpty);

        // But should still remove sync
        expect(span.removeDataCalls.length, equals(1));
        expect(span.removeDataCalls.first.key, equals('sync'));
      },
    );
  });

  group('$ThreadInfoIntegration with streaming lifecycle', () {
    setUp(() {
      fixture.options.dsn = fakeDsn;
      fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
    });

    group('when a span starts', () {
      test('sets main thread name when in root isolate', () async {
        fixture.mockHelper.setIsRootIsolate(true);
        fixture.mockHelper.setIsolateName('main(debug)');

        final hub = Hub(fixture.options);
        final integration = fixture.getSut();
        integration.call(hub, fixture.options);

        final span = fixture.startStreamingSpan(hub);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanStartV2(span),
        );

        expect(
          span.attributes[SemanticAttributesConstants.threadId]?.value,
          equals('main'.hashCode.toString()),
        );
        expect(
          span.attributes[SemanticAttributesConstants.threadName]?.value,
          equals('main'),
        );
      });

      test('adds thread information when isolate has name', () async {
        fixture.mockHelper.setIsRootIsolate(false);
        fixture.mockHelper.setIsolateName('worker-thread');

        final hub = Hub(fixture.options);
        final integration = fixture.getSut();
        integration.call(hub, fixture.options);

        final span = fixture.startStreamingSpan(hub);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanStartV2(span),
        );

        expect(
          span.attributes[SemanticAttributesConstants.threadId]?.value,
          equals('worker-thread'.hashCode.toString()),
        );
        expect(
          span.attributes[SemanticAttributesConstants.threadName]?.value,
          equals('worker-thread'),
        );
      });

      test('does not set thread info when isolate name is null', () async {
        fixture.mockHelper.setIsRootIsolate(false);
        fixture.mockHelper.setIsolateName(null);

        final hub = Hub(fixture.options);
        final integration = fixture.getSut();
        integration.call(hub, fixture.options);

        final span = fixture.startStreamingSpan(hub);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanStartV2(span),
        );

        expect(
          span.attributes.containsKey(SemanticAttributesConstants.threadId),
          isFalse,
        );
        expect(
          span.attributes.containsKey(SemanticAttributesConstants.threadName),
          isFalse,
        );
      });

      test('does not set thread info when isolate name is empty', () async {
        fixture.mockHelper.setIsRootIsolate(false);
        fixture.mockHelper.setIsolateName('');

        final hub = Hub(fixture.options);
        final integration = fixture.getSut();
        integration.call(hub, fixture.options);

        final span = fixture.startStreamingSpan(hub);
        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnSpanStartV2(span),
        );

        expect(
          span.attributes.containsKey(SemanticAttributesConstants.threadId),
          isFalse,
        );
        expect(
          span.attributes.containsKey(SemanticAttributesConstants.threadName),
          isFalse,
        );
      });
    });

    group('when a span is processed', () {
      test(
        'sets blocked_main_thread when sync span is on main isolate',
        () async {
          final hub = Hub(fixture.options);
          final integration = fixture.getSut();
          integration.call(hub, fixture.options);

          final span = fixture.startStreamingSpan(hub);
          span.setAttribute('sync', SentryAttribute.bool(true));
          span.setAttribute(
            SemanticAttributesConstants.threadName,
            SentryAttribute.string('main'),
          );

          await fixture.options.lifecycleRegistry.dispatchCallback(
            OnProcessSpan(span, Hint()),
          );

          expect(
            span
                .attributes[SemanticAttributesConstants.blockedMainThread]
                ?.value,
            isTrue,
          );
          // sync marker is stripped, never sent
          expect(span.attributes.containsKey('sync'), isFalse);
        },
      );

      test(
        'does not set blocked_main_thread when sync span is on background isolate',
        () async {
          final hub = Hub(fixture.options);
          final integration = fixture.getSut();
          integration.call(hub, fixture.options);

          final span = fixture.startStreamingSpan(hub);
          span.setAttribute('sync', SentryAttribute.bool(true));
          span.setAttribute(
            SemanticAttributesConstants.threadName,
            SentryAttribute.string('worker-thread'),
          );

          await fixture.options.lifecycleRegistry.dispatchCallback(
            OnProcessSpan(span, Hint()),
          );

          expect(
            span.attributes.containsKey(
              SemanticAttributesConstants.blockedMainThread,
            ),
            isFalse,
          );
          expect(span.attributes.containsKey('sync'), isFalse);
        },
      );

      test(
        'does not set blocked_main_thread for spans without sync data',
        () async {
          final hub = Hub(fixture.options);
          final integration = fixture.getSut();
          integration.call(hub, fixture.options);

          final span = fixture.startStreamingSpan(hub);
          span.setAttribute(
            SemanticAttributesConstants.threadName,
            SentryAttribute.string('main'),
          );

          await fixture.options.lifecycleRegistry.dispatchCallback(
            OnProcessSpan(span, Hint()),
          );

          expect(
            span.attributes.containsKey(
              SemanticAttributesConstants.blockedMainThread,
            ),
            isFalse,
          );
        },
      );

      test('does not set blocked_main_thread when sync is false', () async {
        final hub = Hub(fixture.options);
        final integration = fixture.getSut();
        integration.call(hub, fixture.options);

        final span = fixture.startStreamingSpan(hub);
        span.setAttribute('sync', SentryAttribute.bool(false));
        span.setAttribute(
          SemanticAttributesConstants.threadName,
          SentryAttribute.string('main'),
        );

        await fixture.options.lifecycleRegistry.dispatchCallback(
          OnProcessSpan(span, Hint()),
        );

        // sync == false is not synchronous, so blocked_main_thread is not set.
        expect(
          span.attributes.containsKey(
            SemanticAttributesConstants.blockedMainThread,
          ),
          isFalse,
        );

        // But the internal marker is still stripped so it never leaks to Sentry.
        expect(span.attributes.containsKey('sync'), isFalse);
      });

      test(
        'does not set blocked_main_thread when sync span has no thread name',
        () async {
          final hub = Hub(fixture.options);
          final integration = fixture.getSut();
          integration.call(hub, fixture.options);

          final span = fixture.startStreamingSpan(hub);
          span.setAttribute('sync', SentryAttribute.bool(true));

          await fixture.options.lifecycleRegistry.dispatchCallback(
            OnProcessSpan(span, Hint()),
          );

          expect(
            span.attributes.containsKey(
              SemanticAttributesConstants.blockedMainThread,
            ),
            isFalse,
          );
          expect(span.attributes.containsKey('sync'), isFalse);
        },
      );
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

  _MockSpan createMockSpanWithData(Map<String, dynamic> data) {
    return _MockSpan.withData(data);
  }

  RecordingSentrySpanV2 startStreamingSpan(Hub hub) {
    return hub.startInactiveSpan('test') as RecordingSentrySpanV2;
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
  final List<_RemoveDataCall> removeDataCalls = [];
  final Map<String, dynamic> _data = {};

  _MockSpan();

  _MockSpan.withData(Map<String, dynamic> data) {
    _data.addAll(data);
  }

  @override
  SentrySpanContext get context => _context;

  @override
  Map<String, dynamic> get data => _data;

  @override
  void setData(String key, dynamic value) {
    setDataCalls.add(_SetDataCall(key, value));
    _data[key] = value;
  }

  @override
  void removeData(String key) {
    removeDataCalls.add(_RemoveDataCall(key));
    _data.remove(key);
  }
}

class _SetDataCall {
  final String key;
  final dynamic value;

  _SetDataCall(this.key, this.value);
}

class _RemoveDataCall {
  final String key;

  _RemoveDataCall(this.key);
}
