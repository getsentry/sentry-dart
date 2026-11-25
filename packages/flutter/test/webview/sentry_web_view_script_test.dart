// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group('$SentryWebViewScript', () {
    late SentryFlutterOptions options;

    setUp(() {
      final transport = MockTransport();
      when(transport.send(any)).thenAnswer((_) async => null);
      options = defaultTestOptions()..transport = transport;
    });
    tearDown(Sentry.close);

    Future<void> init({double rate = 1}) =>
        Sentry.init((o) => o.tracesSampleRate = rate, options: options);

    SentryWebViewScript? build(List<String> hosts) =>
        SentryWebViewScript.build(allowedHosts: hosts);

    test('skips disabled SDKs', () {
      expect(build(['example.com']), isNull);
    });

    test('normalizes and deduplicates HTTPS origin rules', () async {
      await init();
      final result = build([
        ' HTTPS://*.App.Example.com.:8443/path ',
        'app.example.com:8443',
        '127.0.0.1:443',
        '[::1]:8443',
        '::1',
        'xn--mnchen-3ya.de',
      ])!;
      expect(result.allowedOriginRules, {
        'https://app.example.com:8443',
        'https://*.app.example.com:8443',
        'https://127.0.0.1',
        'https://[::1]:8443',
        'https://[::1]',
        'https://xn--mnchen-3ya.de',
        'https://*.xn--mnchen-3ya.de',
      });
    });

    test('records adoption once even when host validation fails', () async {
      await init();
      for (final entry in [
        '',
        '*',
        '*.',
        'user@example.com',
        'foo..bar',
        'münchen.de',
        'example.com:65536',
        'example.com:',
        '127.1',
      ]) {
        expect(build([entry]), isNull, reason: entry);
      }
      expect(
        options.sdk.integrations.where((v) => v == 'WebViewTracePropagation'),
        hasLength(1),
      );
    });

    test('keeps valid hosts when another entry has an invalid port', () async {
      await init();
      final result = build(['bad.example:${'9' * 80}', 'example.com']);
      expect(result?.allowedOriginRules, {
        'https://example.com',
        'https://*.example.com',
      });
    });

    for (final mode in [
      SentryTraceLifecycle.static,
      SentryTraceLifecycle.stream,
    ]) {
      test(
        'preserves fallback sampling decisions in ${mode.name} mode',
        () async {
          options.traceLifecycle = mode;
          await init();
          final context = Sentry.currentHub.scope.propagationContext;
          for (final decision in [null, false, true]) {
            context.generateNewTrace();
            if (decision != null) context.applySamplingDecision(decision);
            final source = build(['example.com'])!.source;
            final suffix = decision == null ? '' : (decision ? '-1' : '-0');
            expect(
              source,
              matches(RegExp('"${context.traceId}-[0-9a-f]{16}$suffix"')),
            );
          }
        },
      );
    }

    test('preserves the active legacy span header', () async {
      options.traceLifecycle = SentryTraceLifecycle.static;
      await init();
      final span = Sentry.startTransaction(
        'private-name',
        'test',
        bindToScope: true,
      );
      final source = build(['example.com'])!.source;
      expect(source, contains(span.toSentryTrace().value));
      expect(source, isNot(contains('sentry-transaction')));
    });

    test(
      'uses the idle span and the recording parent inside an ignored child',
      () async {
        await init();
        options.ignoreSpans = [IgnoreSpanRule.nameEquals('ignored')];
        final hub = Sentry.currentHub;
        hub.startSpanSync('ignored', (_) {
          expect(
            build(['example.com'])!.source,
            contains(hub.scope.propagationContext.traceId.toString()),
          );
          expect(hub.getActiveSpan(), isNull);
        });
        final idle = hub.startIdleSpan('navigation');
        expect(
          build(['example.com'])!.source,
          contains('${idle.traceId}-${idle.spanId}-1'),
        );
        hub.startSpanSync('parent', (parent) {
          hub.startSpanSync('ignored', (_) {
            expect(
              build(['example.com'])!.source,
              contains('${parent.traceId}-${parent.spanId}-1'),
            );
          });
        });
        idle.end();
      },
    );

    test(
      'preserves the rejected root decision until the trace rotates',
      () async {
        await init(rate: 0);
        final hub = Sentry.currentHub;
        hub.startSpanSync('root', (_) {});
        final context = hub.scope.propagationContext;
        final rejected = build(['example.com'])!.source;
        expect(
          rejected,
          matches(RegExp('"${context.traceId}-[0-9a-f]{16}-0"')),
        );
        expect(rejected, contains('sentry-sample_rand=${context.sampleRand}'));
        hub.generateNewTrace();
        expect(
          build(['example.com'])!.source,
          matches(RegExp('"${context.traceId}-[0-9a-f]{16}"')),
        );
      },
    );
  });
}
