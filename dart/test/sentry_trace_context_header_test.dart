import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('$SentryTraceContextHeader', () {
    final traceId = SentryId.newId();

    final context = SentryTraceContextHeader(
      traceId,
      '123',
      release: 'release',
      environment: 'environment',
      userId: 'user_id',
      userSegment: 'user_segment',
      transaction: 'transaction',
      sampleRate: '1.0',
      sampled: 'false',
      replayId: SentryId.fromId('456'),
      unknown: testUnknown,
    );

    final mapJson = <String, dynamic>{
      'trace_id': '$traceId',
      'public_key': '123',
      'release': 'release',
      'environment': 'environment',
      'user_id': 'user_id',
      'user_segment': 'user_segment',
      'transaction': 'transaction',
      'sample_rate': '1.0',
      'sampled': 'false',
      'replay_id': '456',
    };
    mapJson.addAll(testUnknown);

    test('fromJson', () {
      expect(context.traceId.toString(), traceId.toString());
      expect(context.publicKey, '123');
      expect(context.release, 'release');
      expect(context.environment, 'environment');
      expect(context.userId, 'user_id');
      // ignore: deprecated_member_use_from_same_package
      expect(context.userSegment, 'user_segment');
      expect(context.transaction, 'transaction');
      expect(context.sampleRate, '1.0');
      expect(context.sampled, 'false');
      expect(context.replayId, SentryId.fromId('456'));
    });

    test('toJson', () {
      final json = context.toJson();

      expect(MapEquality().equals(json, mapJson), isTrue);
    });

    test('to baggage', () {
      final baggage = context.toBaggage();

      expect(
        baggage.toHeaderString(),
        'sentry-trace_id=${traceId.toString()},'
        'sentry-public_key=123,'
        'sentry-release=release,'
        'sentry-environment=environment,'
        'sentry-user_id=user_id,'
        'sentry-user_segment=user_segment,'
        'sentry-transaction=transaction,'
        'sentry-sample_rate=1.0,'
        'sentry-sampled=false,'
        'sentry-replay_id=456',
      );
    });
  });
}
