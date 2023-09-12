import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryTraceContextHeader', () {
    final id = SentryId.newId();
    final mapJson = <String, dynamic>{
      'trace_id': '$id',
      'public_key': '123',
      'release': 'release',
      'environment': 'environment',
      'user_id': 'user_id',
      'user_segment': 'user_segment',
      'transaction': 'transaction',
      'sample_rate': '1.0',
      'sampled': 'false'
    };
    final context = SentryTraceContextHeader.fromJson(mapJson);

    test('fromJson', () {
      expect(context.traceId.toString(), id.toString());
      expect(context.publicKey, '123');
      expect(context.release, 'release');
      expect(context.environment, 'environment');
      expect(context.userId, 'user_id');
      expect(context.userSegment, 'user_segment');
      expect(context.transaction, 'transaction');
      expect(context.sampleRate, '1.0');
      expect(context.sampled, 'false');
    });

    test('toJson', () {
      final json = context.toJson();

      expect(MapEquality().equals(json, mapJson), isTrue);
    });

    test('to baggage', () {
      final baggage = context.toBaggage();

      expect(baggage.toHeaderString(),
          'sentry-trace_id=${id.toString()},sentry-public_key=123,sentry-release=release,sentry-environment=environment,sentry-user_id=user_id,sentry-user_segment=user_segment,sentry-transaction=transaction,sentry-sample_rate=1.0,sentry-sampled=false');
    });
  });
}
