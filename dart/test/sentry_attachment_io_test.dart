@TestOn('vm')
library dart_test;

import 'dart:io';

import 'package:sentry/sentry_io.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryAttachment ctor', () {
    test('fromFile', () async {
      final file = File('test_resources/testfile.txt');

      final attachment = IoSentryAttachment.fromFile(file);
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'testfile.txt');
      await expectLater(
          await attachment.bytes, [102, 111, 111, 32, 98, 97, 114]);
    });

    test('fromPath', () async {
      final attachment =
          IoSentryAttachment.fromPath('test_resources/testfile.txt');
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'testfile.txt');
      await expectLater(
          await attachment.bytes, [102, 111, 111, 32, 98, 97, 114]);
    });
  });
}
