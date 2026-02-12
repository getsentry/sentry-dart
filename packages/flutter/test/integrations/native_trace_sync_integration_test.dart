// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_trace_sync_integration.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';

void main() {
  group(NativeTraceSyncIntegration, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds integration', () {
      fixture.registerIntegration();

      expect(fixture.options.sdk.integrations,
          contains(NativeTraceSyncIntegration.integrationName));
    });

    test('syncs initial propagation context on registration', () {
      fixture.registerIntegration();

      final call = fixture.binding.setTraceCalls.single;
      expect(call.traceId, fixture.hub.scope.propagationContext.traceId);
    });

    test('syncs trace when OnTraceReset is dispatched', () {
      fixture.registerIntegration();
      fixture.binding.setTraceCalls.clear();

      fixture.hub.generateNewTrace();

      // We cannot assert that the trace propagated to native here
      // instead we just assert that the call was made with the correct trace ID.
      final call = fixture.binding.setTraceCalls.single;
      expect(call.traceId, fixture.hub.scope.propagationContext.traceId);
    });

    test('unregisters callback on close', () {
      fixture.registerIntegration();
      fixture.binding.setTraceCalls.clear();

      fixture.sut.close();
      fixture.hub.generateNewTrace();

      expect(fixture.binding.setTraceCalls, isEmpty);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final binding = _FakeNativeBinding();
  late final hub = Hub(options);
  late final sut = NativeTraceSyncIntegration(binding);

  void registerIntegration() {
    sut.call(hub, options);
  }
}

class _SetTraceCall {
  final SentryId traceId;
  final SpanId spanId;

  _SetTraceCall(this.traceId, this.spanId);
}

class _FakeNativeBinding extends Fake implements SentryNativeBinding {
  final setTraceCalls = <_SetTraceCall>[];

  @override
  void setTrace(SentryId traceId, SpanId spanId) {
    setTraceCalls.add(_SetTraceCall(traceId, spanId));
  }
}
