import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/tracing_utils.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('extractOrgIdFromDsnHost', () {
    test('extracts org id from standard host', () {
      expect(extractOrgIdFromDsnHost('o123.ingest.sentry.io'), '123');
    });

    test('extracts single digit org id', () {
      expect(extractOrgIdFromDsnHost('o1.ingest.us.sentry.io'), '1');
    });

    test('extracts large org id', () {
      expect(extractOrgIdFromDsnHost('o9999999.ingest.sentry.io'), '9999999');
    });

    test('returns null for host without org prefix', () {
      expect(extractOrgIdFromDsnHost('sentry.io'), isNull);
    });

    test('returns null for localhost', () {
      expect(extractOrgIdFromDsnHost('localhost'), isNull);
    });

    test('returns null for empty string', () {
      expect(extractOrgIdFromDsnHost(''), isNull);
    });

    test('returns null for non-numeric org id', () {
      expect(extractOrgIdFromDsnHost('oabc.ingest.sentry.io'), isNull);
    });
  });

  group('SentryOptions', () {
    group('effectiveOrgId', () {
      test('returns null when neither orgId nor DSN org id are set', () {
        final options = defaultTestOptions();
        expect(options.effectiveOrgId, isNull);
      });

      test('returns explicit orgId when set', () {
        final options = defaultTestOptions()..orgId = '456';
        expect(options.effectiveOrgId, '456');
      });

      test('returns DSN-extracted org id when orgId is not set', () {
        final options = SentryOptions(
            dsn: 'https://public@o123.ingest.sentry.io/1')
          ..automatedTestMode = true;
        expect(options.effectiveOrgId, '123');
      });

      test('prefers explicit orgId over DSN-extracted org id', () {
        final options = SentryOptions(
            dsn: 'https://public@o123.ingest.sentry.io/1')
          ..automatedTestMode = true
          ..orgId = '456';
        expect(options.effectiveOrgId, '456');
      });
    });

    test('strictTraceContinuation defaults to false', () {
      final options = defaultTestOptions();
      expect(options.strictTraceContinuation, isFalse);
    });

    test('orgId defaults to null', () {
      final options = defaultTestOptions();
      expect(options.orgId, isNull);
    });
  });

  group('shouldContinueTrace', () {
    test('returns true when both org IDs are null', () {
      final options = defaultTestOptions();
      expect(shouldContinueTrace(options, null), isTrue);
    });

    test('returns true when org IDs match', () {
      final options = defaultTestOptions()..orgId = '123';
      expect(shouldContinueTrace(options, '123'), isTrue);
    });

    test('returns false when org IDs do not match', () {
      final options = defaultTestOptions()..orgId = '123';
      expect(shouldContinueTrace(options, '456'), isFalse);
    });

    group('when strictTraceContinuation is false', () {
      test('continues trace when baggage org ID is missing', () {
        final options = defaultTestOptions()
          ..orgId = '123'
          ..strictTraceContinuation = false;
        expect(shouldContinueTrace(options, null), isTrue);
      });

      test('continues trace when SDK org ID is missing', () {
        final options = defaultTestOptions()
          ..strictTraceContinuation = false;
        expect(shouldContinueTrace(options, '123'), isTrue);
      });
    });

    group('when strictTraceContinuation is true', () {
      test('starts new trace when baggage org ID is missing', () {
        final options = defaultTestOptions()
          ..orgId = '123'
          ..strictTraceContinuation = true;
        expect(shouldContinueTrace(options, null), isFalse);
      });

      test('starts new trace when SDK org ID is missing', () {
        final options = defaultTestOptions()
          ..strictTraceContinuation = true;
        expect(shouldContinueTrace(options, '123'), isFalse);
      });

      test('continues trace when both org IDs are missing', () {
        final options = defaultTestOptions()
          ..strictTraceContinuation = true;
        expect(shouldContinueTrace(options, null), isTrue);
      });

      test('continues trace when org IDs match', () {
        final options = defaultTestOptions()
          ..orgId = '123'
          ..strictTraceContinuation = true;
        expect(shouldContinueTrace(options, '123'), isTrue);
      });

      test('starts new trace when org IDs do not match', () {
        final options = defaultTestOptions()
          ..orgId = '123'
          ..strictTraceContinuation = true;
        expect(shouldContinueTrace(options, '456'), isFalse);
      });
    });
  });

  group('SentryBaggage', () {
    test('sets and gets org_id', () {
      final baggage = SentryBaggage({});
      baggage.setOrgId('123');
      expect(baggage.getOrgId(), '123');
    });

    test('returns null for missing org_id', () {
      final baggage = SentryBaggage({});
      expect(baggage.getOrgId(), isNull);
    });

    test('setValuesFromScope includes org_id when available', () {
      final options = SentryOptions(
          dsn: 'https://public@o123.ingest.sentry.io/1')
        ..automatedTestMode = true;
      final scope = Scope(options);
      final baggage = SentryBaggage({});

      baggage.setValuesFromScope(scope, options);
      expect(baggage.getOrgId(), '123');
    });

    test('setValuesFromScope includes explicit orgId', () {
      final options = defaultTestOptions()..orgId = '456';
      final scope = Scope(options);
      final baggage = SentryBaggage({});

      baggage.setValuesFromScope(scope, options);
      expect(baggage.getOrgId(), '456');
    });

    test('setValuesFromScope does not include org_id when not available', () {
      final options = defaultTestOptions();
      final scope = Scope(options);
      final baggage = SentryBaggage({});

      baggage.setValuesFromScope(scope, options);
      expect(baggage.getOrgId(), isNull);
    });

    test('org_id is included in header string', () {
      final baggage = SentryBaggage({});
      baggage.setOrgId('123');
      expect(baggage.toHeaderString(), contains('sentry-org_id=123'));
    });
  });

  group('SentryTraceContextHeader', () {
    test('includes orgId in toBaggage', () {
      final context = SentryTraceContextHeader(
        SentryId.newId(),
        'publicKey',
        orgId: '123',
      );
      final baggage = context.toBaggage();
      expect(baggage.getOrgId(), '123');
    });

    test('does not include orgId in toBaggage when null', () {
      final context = SentryTraceContextHeader(
        SentryId.newId(),
        'publicKey',
      );
      final baggage = context.toBaggage();
      expect(baggage.getOrgId(), isNull);
    });

    test('includes orgId in toJson', () {
      final context = SentryTraceContextHeader(
        SentryId.newId(),
        'publicKey',
        orgId: '123',
      );
      final json = context.toJson();
      expect(json['org_id'], '123');
    });

    test('reads orgId from fromJson', () {
      final context = SentryTraceContextHeader.fromJson({
        'trace_id': SentryId.newId().toString(),
        'public_key': 'publicKey',
        'org_id': '123',
      });
      expect(context.orgId, '123');
    });

    test('reads orgId from fromBaggage', () {
      final baggage = SentryBaggage({});
      baggage.setTraceId(SentryId.newId().toString());
      baggage.setPublicKey('publicKey');
      baggage.setOrgId('123');

      final context = SentryTraceContextHeader.fromBaggage(baggage);
      expect(context.orgId, '123');
    });
  });

  group('SentryTransactionContext', () {
    final traceId = SentryId.fromId('12312012123120121231201212312012');
    final spanId = SpanId.fromId('1121201211212012');

    group('fromSentryTrace', () {
      test('continues trace when org IDs match', () {
        final options = defaultTestOptions()..orgId = '123';
        final header =
            SentryTraceHeader(traceId, spanId, sampled: true);
        final baggage = SentryBaggage({})..setOrgId('123');

        final context = SentryTransactionContext.fromSentryTrace(
          'name',
          'op',
          header,
          baggage: baggage,
          options: options,
        );

        expect(context.traceId, traceId);
        expect(context.parentSpanId, spanId);
      });

      test('starts new trace when org IDs do not match', () {
        final options = defaultTestOptions()..orgId = '123';
        final header =
            SentryTraceHeader(traceId, spanId, sampled: true);
        final baggage = SentryBaggage({})..setOrgId('456');

        final context = SentryTransactionContext.fromSentryTrace(
          'name',
          'op',
          header,
          baggage: baggage,
          options: options,
        );

        expect(context.traceId, isNot(traceId));
        expect(context.parentSpanId, isNull);
      });

      test('continues trace when options is null (backwards compat)', () {
        final header =
            SentryTraceHeader(traceId, spanId, sampled: true);
        final baggage = SentryBaggage({})..setOrgId('456');

        final context = SentryTransactionContext.fromSentryTrace(
          'name',
          'op',
          header,
          baggage: baggage,
        );

        expect(context.traceId, traceId);
        expect(context.parentSpanId, spanId);
      });

      group('when strictTraceContinuation is true', () {
        test('starts new trace when baggage org ID is missing', () {
          final options = defaultTestOptions()
            ..orgId = '123'
            ..strictTraceContinuation = true;
          final header =
              SentryTraceHeader(traceId, spanId, sampled: true);

          final context = SentryTransactionContext.fromSentryTrace(
            'name',
            'op',
            header,
            options: options,
          );

          expect(context.traceId, isNot(traceId));
          expect(context.parentSpanId, isNull);
        });

        test('starts new trace when SDK org ID is missing', () {
          final options = defaultTestOptions()
            ..strictTraceContinuation = true;
          final header =
              SentryTraceHeader(traceId, spanId, sampled: true);
          final baggage = SentryBaggage({})..setOrgId('123');

          final context = SentryTransactionContext.fromSentryTrace(
            'name',
            'op',
            header,
            baggage: baggage,
            options: options,
          );

          expect(context.traceId, isNot(traceId));
          expect(context.parentSpanId, isNull);
        });

        test('continues trace when both org IDs are missing', () {
          final options = defaultTestOptions()
            ..strictTraceContinuation = true;
          final header =
              SentryTraceHeader(traceId, spanId, sampled: true);

          final context = SentryTransactionContext.fromSentryTrace(
            'name',
            'op',
            header,
            options: options,
          );

          expect(context.traceId, traceId);
          expect(context.parentSpanId, spanId);
        });
      });
    });
  });
}
