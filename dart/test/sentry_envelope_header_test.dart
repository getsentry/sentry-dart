import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItemHeader', () {
    test('serialize empty', () async {
      final sut = SentryEnvelopeHeader(null, null);
      final expected = utf8.encode('{}');
      expect(await sut.serialize(), expected);
    });

    test('serialize', () async {
      final eventId = SentryId.newId();
      final sdkVersion = SdkVersion(
        name: 'fixture-sdkName',
        version: 'fixture-version',
      );
      final sut = SentryEnvelopeHeader(eventId, sdkVersion);
      final expextedSkd = jsonEncode(sdkVersion.toJson());
      final expected = utf8.encode('{\"event_id\":\"$eventId\",\"sdk\":$expextedSkd}');
      expect(await sut.serialize(), expected);
    });
  });
}
