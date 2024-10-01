@TestOn('vm')
library dart_test;

import 'dart:convert';
import 'dart:io';

import 'package:sentry/sentry_io.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'test_utils.dart';

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
          .envelopeStream(defaultTestOptions())
          .forEach(envelopeData.addAll);

      final expectedEnvelopeFile =
          File('test_resources/envelope-with-image.envelope');
      final expectedEnvelopeData = await expectedEnvelopeFile.readAsBytes();

      expect(expectedEnvelopeData, envelopeData);
    });

    test('skips attachment if path is invalid', () async {
      final event = SentryEvent(
        eventId: SentryId.empty(),
        timestamp: DateTime.utc(1970, 1, 1),
      );
      final sdkVersion = SdkVersion(name: '', version: '');
      final attachment =
          IoSentryAttachment.fromPath('this_path_does_not_exist.txt');
      final envelope = SentryEnvelope.fromEvent(
        event,
        sdkVersion,
        dsn: fakeDsn,
        attachments: [attachment],
      );

      final data =
          (await envelope.envelopeStream(defaultTestOptions()).toList())
              .reduce((a, b) => a + b);

      final file = File('test_resources/envelope-no-attachment.envelope');
      final jsonStr = await file.readAsString();
      final dataStr = utf8.decode(data);

      expect(dataStr, jsonStr);
    });
  });
}
