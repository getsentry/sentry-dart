import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeHeader', () {
    test('toJson empty', () {
      final sut = SentryEnvelopeHeader(null, null);
      final expected = <String, dynamic>{};
      expect(sut.toJson(), expected);
    });

    test('toJson', () async {
      final eventId = SentryId.newId();
      final sdkVersion = SdkVersion(
        name: 'fixture-sdkName',
        version: 'fixture-version',
      );
      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final sut = SentryEnvelopeHeader(
        eventId,
        sdkVersion,
        traceContext: context,
      );
      final expextedSkd = sdkVersion.toJson();
      final expected = <String, dynamic>{
        'event_id': eventId.toString(),
        'sdk': expextedSkd,
        'trace': context.toJson(),
      };
      expect(sut.toJson(), expected);
    });
  });
}
