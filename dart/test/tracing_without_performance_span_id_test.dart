import 'package:sentry/sentry.dart';
import 'package:sentry/src/propagation_context.dart';
import 'package:sentry/src/sentry_trace_context.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Tracing without performance - span ID consistency', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('span ID should be consistent between event trace context and HTTP headers', () async {
      final hub = fixture.hub;
      
      // Disable performance tracing
      hub.options.tracesSampleRate = null;
      hub.options.tracesSampler = null;
      
      // Get the propagation context
      final propagationContext = hub.scope.propagationContext;
      
      // Get the span ID from the HTTP header
      final traceHeader = propagationContext.toSentryTrace();
      final headerSpanId = traceHeader.spanId;
      
      // Create an event and apply scope to it
      final event = SentryEvent();
      final processedEvent = await hub.scope.applyToEvent(event, Hint());
      
      // Get the span ID from the event's trace context
      final eventSpanId = processedEvent?.contexts.trace?.spanId;
      
      // They should be the same
      expect(eventSpanId, equals(headerSpanId));
      expect(eventSpanId, isNotNull);
    });

    test('span ID should remain consistent across multiple toSentryTrace calls', () async {
      final hub = fixture.hub;
      
      // Disable performance tracing
      hub.options.tracesSampleRate = null;
      hub.options.tracesSampler = null;
      
      final propagationContext = hub.scope.propagationContext;
      
      // Get span IDs from multiple HTTP headers
      final traceHeader1 = propagationContext.toSentryTrace();
      final traceHeader2 = propagationContext.toSentryTrace();
      
      // They should be the same (cached)
      expect(traceHeader1.spanId, equals(traceHeader2.spanId));
    });

    test('span ID should change for new requests after generateNewTraceId', () async {
      final hub = fixture.hub;
      
      // Disable performance tracing
      hub.options.tracesSampleRate = null;
      hub.options.tracesSampler = null;
      
      final propagationContext = hub.scope.propagationContext;
      
      // Get initial IDs
      final initialTraceId = propagationContext.traceId;
      final initialHeader = propagationContext.toSentryTrace();
      final initialSpanId = initialHeader.spanId;
      
      // Generate new trace ID (simulating a new request)
      hub.generateNewTraceId();
      
      // Get new IDs
      final newTraceId = propagationContext.traceId;
      final newHeader = propagationContext.toSentryTrace();
      final newSpanId = newHeader.spanId;
      
      // Trace ID should be different
      expect(newTraceId, isNot(equals(initialTraceId)));
      // Span ID should also be different (new request = new span)
      expect(newSpanId, isNot(equals(initialSpanId)));
      // Header should reflect new IDs
      expect(newHeader.traceId, equals(newTraceId));
      expect(newHeader.spanId, equals(newSpanId));
    });

    test('cloned scope should have the same cached trace header', () async {
      final hub = fixture.hub;
      
      // Disable performance tracing
      hub.options.tracesSampleRate = null;
      hub.options.tracesSampler = null;
      
      final originalScope = hub.scope;
      
      // Generate a trace header to cache it
      final originalHeader = originalScope.propagationContext.toSentryTrace();
      
      // Clone the scope
      final clonedScope = originalScope.clone();
      
      // Get the header from the cloned scope
      final clonedHeader = clonedScope.propagationContext.toSentryTrace();
      
      // Propagation context IDs should be the same
      expect(clonedScope.propagationContext.traceId, equals(originalScope.propagationContext.traceId));
      expect(clonedHeader.spanId, equals(originalHeader.spanId));
      
      // But they should be independent objects
      expect(identical(clonedScope.propagationContext, originalScope.propagationContext), isFalse);
    });
    
    test('span ID consistency between HTTP client and event capture', () async {
      final hub = fixture.hub;
      
      // Disable performance tracing
      hub.options.tracesSampleRate = null;
      hub.options.tracesSampler = null;
      
      // Simulate HTTP request getting the trace header
      final httpTraceHeader = hub.scope.propagationContext.toSentryTrace();
      
      // Simulate an error occurring during the HTTP request
      final event = SentryEvent(throwable: Exception('Test error'));
      final processedEvent = await hub.scope.applyToEvent(event, Hint());
      
      // The span ID in the event should match the HTTP header
      expect(processedEvent?.contexts.trace?.spanId, equals(httpTraceHeader.spanId));
      expect(processedEvent?.contexts.trace?.traceId, equals(httpTraceHeader.traceId));
    });
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);
  late final hub = Hub(options);

  Fixture() {
    options.enableScopeSync = false;
  }
} 