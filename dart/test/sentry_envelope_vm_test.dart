@TestOn('vm')
import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
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
      await envelope.envelopeStream().forEach(envelopeData.addAll);

      final expectedEnvelopeFile =
          File('test_resources/envelope-with-image.envelope');
      final expectedEnvelopeData = await expectedEnvelopeFile.readAsBytes();

      expect(expectedEnvelopeData, envelopeData);
    });
  });
}
