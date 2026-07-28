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

    test('does not add integration if enableNativeTraceSync is false', () {
      fixture.options.enableNativeTraceSync = false;
      fixture.registerIntegration();

      expect(fixture.options.sdk.integrations,
          isNot(contains(NativeTraceSyncIntegration.integrationName)));
    });

    test('does not sync trace if enableNativeTraceSync is false', () {
      fixture.options.enableNativeTraceSync = false;
      fixture.registerIntegration();

      fixture.hub.generateNewTrace();

      expect(fixture.binding.setTraceCalls, isEmpty);
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

    test('does not surface error when native setTrace fails', () async {
      fixture.binding.throwOnSetTrace = true;

      // The initial sync during call() is fire-and-forget, and the
      // OnGenerateNewTrace callback may run unawaited too. A native failure
      // must be caught internally; otherwise it surfaces as an unhandled
      // async error that can outlive the test and fail it.
      fixture.registerIntegration();
      fixture.hub.generateNewTrace();

      await pumpEventQueue();

      expect(fixture.binding.setTraceCalls, isNotEmpty);
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
  bool throwOnSetTrace = false;

  @override
  Future<void> setTrace(SentryId traceId, SpanId spanId) async {
    setTraceCalls.add(_SetTraceCall(traceId, spanId));
    if (throwOnSetTrace) {
      // Mirrors the channel binding rejecting with MissingPluginException.
      throw Exception('native setTrace failed');
    }
  }
}
