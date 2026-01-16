import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/enricher/enricher.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../../mocks/mock_telemetry_attributes_provider.dart';
import '../../test_utils.dart';

void main() {
  group('$TelemetryEnricher', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when adding providers', () {
      test('adds new provider', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'value1'});

        enricher.addAttributesProvider(provider);

        final log = fixture.createLog();
        await enricher.enrichLog(log);

        expect(log.attributes['key']?.value, 'value1');
      });

      test('does not add duplicate provider', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'value1'});

        enricher.addAttributesProvider(provider);
        enricher.addAttributesProvider(provider);

        final log = fixture.createLog();
        await enricher.enrichLog(log);

        expect(log.attributes['key']?.value, 'value1');
        expect(provider.callCount, 1);
      });
    });

    group('when enriching logs', () {
      test('merges attributes with correct priority', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'provider'});
        enricher.addAttributesProvider(provider);

        final scope = fixture.createScope({'key': 'scope'});
        final log = fixture.createLog({'key': 'item'});

        await enricher.enrichLog(log, scope: scope);

        expect(log.attributes['key']?.value, 'item');
      });

      test('preserves existing log attributes', () async {
        final enricher = fixture.getSut();
        final log = fixture.createLog({'existing': 'value'});

        await enricher.enrichLog(log);

        expect(log.attributes['existing']?.value, 'value');
      });

      test('includes scope attributes', () async {
        final enricher = fixture.getSut();
        final scope = fixture.createScope({'scope_key': 'scope_value'});
        final log = fixture.createLog();

        await enricher.enrichLog(log, scope: scope);

        expect(log.attributes['scope_key']?.value, 'scope_value');
      });

      test('includes provider attributes', () async {
        final enricher = fixture.getSut();
        final provider =
            fixture.createProvider({'provider_key': 'provider_value'});
        enricher.addAttributesProvider(provider);

        final log = fixture.createLog();
        await enricher.enrichLog(log);

        expect(log.attributes['provider_key']?.value, 'provider_value');
      });

      test('handles null scope', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'value'});
        enricher.addAttributesProvider(provider);

        final log = fixture.createLog();
        await enricher.enrichLog(log, scope: null);

        expect(log.attributes['key']?.value, 'value');
      });

      test('scope attributes override provider attributes', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'provider'});
        enricher.addAttributesProvider(provider);

        final scope = fixture.createScope({'key': 'scope'});
        final log = fixture.createLog();

        await enricher.enrichLog(log, scope: scope);

        expect(log.attributes['key']?.value, 'scope');
      });
    });

    group('when enriching spans', () {
      test('merges attributes with correct priority', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'provider'});
        enricher.addAttributesProvider(provider);

        final scope = fixture.createScope({'key': 'scope'});
        final span = fixture.createSpan({'key': 'item'});

        await enricher.enrichSpan(span, scope: scope);

        expect(span.attributes['key']?.value, 'item');
      });

      test('preserves existing span attributes', () async {
        final enricher = fixture.getSut();
        final span = fixture.createSpan({'existing': 'value'});

        await enricher.enrichSpan(span);

        expect(span.attributes['existing']?.value, 'value');
      });

      test('includes scope attributes', () async {
        final enricher = fixture.getSut();
        final scope = fixture.createScope({'scope_key': 'scope_value'});
        final span = fixture.createSpan();

        await enricher.enrichSpan(span, scope: scope);

        expect(span.attributes['scope_key']?.value, 'scope_value');
      });

      test('includes provider attributes', () async {
        final enricher = fixture.getSut();
        final provider =
            fixture.createProvider({'provider_key': 'provider_value'});
        enricher.addAttributesProvider(provider);

        final span = fixture.createSpan();
        await enricher.enrichSpan(span);

        expect(span.attributes['provider_key']?.value, 'provider_value');
      });

      test('calls setAttributes on span', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'value'});
        enricher.addAttributesProvider(provider);

        final span = fixture.createSpan();
        final initialAttributeCount = span.attributes.length;

        await enricher.enrichSpan(span);

        expect(span.attributes.length, greaterThan(initialAttributeCount));
        expect(span.attributes['key']?.value, 'value');
      });

      test('handles null scope', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'value'});
        enricher.addAttributesProvider(provider);

        final span = fixture.createSpan();
        await enricher.enrichSpan(span, scope: null);

        expect(span.attributes['key']?.value, 'value');
      });

      test('scope attributes override provider attributes', () async {
        final enricher = fixture.getSut();
        final provider = fixture.createProvider({'key': 'provider'});
        enricher.addAttributesProvider(provider);

        final scope = fixture.createScope({'key': 'scope'});
        final span = fixture.createSpan();

        await enricher.enrichSpan(span, scope: scope);

        expect(span.attributes['key']?.value, 'scope');
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  TelemetryEnricher getSut() {
    return TelemetryEnricher();
  }

  SentryLog createLog([Map<String, String>? attributes]) {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: 'test log',
      attributes: attributes != null
          ? <String, SentryAttribute>{
              ...attributes
                  .map((k, v) => MapEntry(k, SentryAttribute.string(v))),
            }
          : <String, SentryAttribute>{},
    );
  }

  RecordingSentrySpanV2 createSpan([Map<String, String>? attributes]) {
    final span = RecordingSentrySpanV2.root(
      name: 'test-span',
      traceId: SentryId.newId(),
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );

    if (attributes != null) {
      span.setAttributes(<String, SentryAttribute>{
        ...attributes.map((k, v) => MapEntry(k, SentryAttribute.string(v))),
      });
    }

    return span;
  }

  Scope createScope([Map<String, String>? attributes]) {
    final scope = Scope(options);
    if (attributes != null) {
      scope.setAttributes(
        attributes.map((k, v) => MapEntry(k, SentryAttribute.string(v))),
      );
    }
    return scope;
  }

  MockTelemetryAttributesProvider createProvider(
      Map<String, String> attributes) {
    return MockTelemetryAttributesProvider(attributes);
  }
}
