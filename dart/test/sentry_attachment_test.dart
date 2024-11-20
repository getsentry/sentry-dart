import 'dart:typed_data';

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks/mock_transport.dart';
import 'test_utils.dart';

void main() {
  group('$SentryAttachment ctor', () {
    test('default', () async {
      final attachment = SentryAttachment.fromLoader(
        loader: () => Uint8List.fromList([0, 0, 0, 0]),
        filename: 'test.txt',
      );
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'test.txt');
      await expectLater(await attachment.bytes, [0, 0, 0, 0]);
    });

    test('fromIntList', () async {
      final attachment = SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt');
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'test.txt');
      await expectLater(await attachment.bytes, [0, 0, 0, 0]);
    });

    test('fromUint8List', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
      );
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'test.txt');
      await expectLater(await attachment.bytes, [0, 0, 0, 0]);
    });

    test('fromByteData', () async {
      final attachment = SentryAttachment.fromByteData(
        ByteData.sublistView(Uint8List.fromList([0, 0, 0, 0])),
        'test.txt',
      );
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, isNull);
      expect(attachment.filename, 'test.txt');
      await expectLater(await attachment.bytes, [0, 0, 0, 0]);
    });
  });

  group('$Scope $SentryAttachment tests', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('Sending with attachments', () async {
      final sut = fixture.getSut();
      await sut.captureEvent(SentryEvent(), withScope: (scope) {
        scope.addAttachment(
          SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt'),
        );
      });
      expect(fixture.transport.envelopes.length, 1);
      expect(fixture.transport.envelopes.first.items.length, 2);
      final attachmentEnvelope = fixture.transport.envelopes.first.items[1];
      expect(
        attachmentEnvelope.header.attachmentType,
        SentryAttachment.typeAttachmentDefault,
      );
      expect(
        attachmentEnvelope.header.contentType,
        isNull,
      );
      expect(
        attachmentEnvelope.header.fileName,
        'test.txt',
      );
      await expectLater(
        await attachmentEnvelope.header.length(),
        4,
      );
    });
  });

  group('addToTransactions', () {
    test('defaults to false fromLoader', () async {
      final attachment = SentryAttachment.fromLoader(
        loader: () => Uint8List.fromList([0, 0, 0, 0]),
        filename: 'test.txt',
      );

      expect(attachment.addToTransactions, false);
    });

    test('defaults to false fromIntList', () async {
      final attachment = SentryAttachment.fromIntList([0, 0, 0, 0], 'test.txt');

      expect(attachment.addToTransactions, false);
    });

    test('defaults to false fromUint8List', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
      );

      expect(attachment.addToTransactions, false);
    });

    test('defaults to false fromByteData', () async {
      final attachment = SentryAttachment.fromByteData(
        ByteData.sublistView(Uint8List.fromList([0, 0, 0, 0])),
        'test.txt',
      );

      expect(attachment.addToTransactions, false);
    });

    test('set fromLoader', () async {
      final attachment = SentryAttachment.fromLoader(
        loader: () => Uint8List.fromList([0, 0, 0, 0]),
        filename: 'test.txt',
        addToTransactions: true,
      );

      expect(attachment.addToTransactions, true);
    });

    test('defaults to false fromIntList', () async {
      final attachment = SentryAttachment.fromIntList(
        [0, 0, 0, 0],
        'test.txt',
        addToTransactions: true,
      );

      expect(attachment.addToTransactions, true);
    });

    test('defaults to false fromUint8List', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
        addToTransactions: true,
      );

      expect(attachment.addToTransactions, true);
    });

    test('defaults to false fromByteData', () async {
      final attachment = SentryAttachment.fromByteData(
        ByteData.sublistView(Uint8List.fromList([0, 0, 0, 0])),
        'test.txt',
        addToTransactions: true,
      );

      expect(attachment.addToTransactions, true);
    });

    test('fromScreenshotData', () async {
      final attachment =
          SentryAttachment.fromScreenshotData(Uint8List.fromList([0, 0, 0, 0]));
      expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
      expect(attachment.contentType, 'image/png');
      expect(attachment.filename, 'screenshot.png');
      expect(attachment.addToTransactions, false);
    });

    test('fromViewHierarchy', () async {
      final view = SentryViewHierarchy('flutter');
      final attachment = SentryAttachment.fromViewHierarchy(view);

      expect(attachment.attachmentType, SentryAttachment.typeViewHierarchy);
      expect(attachment.contentType, 'application/json');
      expect(attachment.filename, 'view-hierarchy.json');
      expect(attachment.addToTransactions, false);
    });
  });
}

class Fixture {
  MockTransport transport = MockTransport();

  Hub getSut() {
    final options = defaultTestOptions();
    options.transport = transport;
    return Hub(options);
  }
}
