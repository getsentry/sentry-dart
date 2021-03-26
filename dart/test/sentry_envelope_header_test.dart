import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItemHeader', () {
    test('serialize empty', () {
      final sut = SentryEnvelopeHeader(null, null);
      final expected = '{}';
      expect(sut.serialize(), expected);
    });

    test('serialize', () {
      final eventId = SentryId.newId();
      final sdkVersion = SdkVersion(
        name: 'fixture-sdkName',
        version: 'fixture-version',
      );
      final sut = SentryEnvelopeHeader(eventId, sdkVersion);
      final expextedSkd = jsonEncode(sdkVersion.toJson());
      final expected = '{\"event_id\":\"$eventId\",\"sdk\":$expextedSkd}';
      expect(sut.serialize(), expected);
    });
  });
}
