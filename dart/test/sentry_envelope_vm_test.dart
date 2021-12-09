@TestOn('vm')
import 'dart:io';

import 'package:sentry/sentry_io.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:test/test.dart';

void main() {
  group('SentryEnvelopeItem', () {
    test('item with binary payload', () async {
      // Attachment

      final length = () async {
        return 3535;
      };
      final dataFactory = () async {
        final file = File('test_resources/sentry.png');
        final bytes = await file.readAsBytes();
        return bytes;
      };
      final attachmentHeader = SentryEnvelopeItemHeader('attachment', length,
          contentType: 'image/png', fileName: 'sentry.png');
      final attachmentItem = SentryEnvelopeItem(attachmentHeader, dataFactory);

      // Envelope

      final eventId = SentryId.fromId('3b382f22ee67491f80f7dee18016a7b1');
      final sdkVersion = SdkVersion(name: 'test', version: 'version');
      final header = SentryEnvelopeHeader(eventId, sdkVersion);
      final envelope = SentryEnvelope(header, [attachmentItem]);

      final envelopeData = <int>[];
      await envelope
          .envelopeStream(SentryOptions())
          .forEach(envelopeData.addAll);

      final expectedEnvelopeFile =
          File('test_resources/envelope-with-image.envelope');
      final expectedEnvelopeData = await expectedEnvelopeFile.readAsBytes();

      expect(expectedEnvelopeData, envelopeData);
    });

    test('skips attachment if path is invalid', () async {
      final event = SentryEvent(
        eventId: SentryId.empty(),
        timestamp: DateTime(1970, 1, 1),
      );
      final sdkVersion = SdkVersion(name: '', version: '');
      final attachment =
          IoSentryAttachment.fromPath('this_path_does_not_exist.txt');

      final envelope = SentryEnvelope.fromEvent(
        event,
        sdkVersion,
        attachments: [attachment],
      );

      final data = (await envelope.envelopeStream(SentryOptions()).toList())
          .reduce((a, b) => a + b);

      expect(data, envelopeBinaryData);
    });
  });
}

final envelopeBinaryData = [
  123,
  34,
  101,
  118,
  101,
  110,
  116,
  95,
  105,
  100,
  34,
  58,
  34,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  34,
  44,
  34,
  115,
  100,
  107,
  34,
  58,
  123,
  34,
  110,
  97,
  109,
  101,
  34,
  58,
  34,
  34,
  44,
  34,
  118,
  101,
  114,
  115,
  105,
  111,
  110,
  34,
  58,
  34,
  34,
  125,
  125,
  10,
  123,
  34,
  99,
  111,
  110,
  116,
  101,
  110,
  116,
  95,
  116,
  121,
  112,
  101,
  34,
  58,
  34,
  97,
  112,
  112,
  108,
  105,
  99,
  97,
  116,
  105,
  111,
  110,
  47,
  106,
  115,
  111,
  110,
  34,
  44,
  34,
  116,
  121,
  112,
  101,
  34,
  58,
  34,
  101,
  118,
  101,
  110,
  116,
  34,
  44,
  34,
  108,
  101,
  110,
  103,
  116,
  104,
  34,
  58,
  56,
  54,
  125,
  10,
  123,
  34,
  101,
  118,
  101,
  110,
  116,
  95,
  105,
  100,
  34,
  58,
  34,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  48,
  34,
  44,
  34,
  116,
  105,
  109,
  101,
  115,
  116,
  97,
  109,
  112,
  34,
  58,
  34,
  49,
  57,
  55,
  48,
  45,
  48,
  49,
  45,
  48,
  49,
  84,
  48,
  48,
  58,
  48,
  48,
  58,
  48,
  48,
  46,
  48,
  48,
  48,
  90,
  34,
  125
];
