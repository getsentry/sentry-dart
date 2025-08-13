import 'dart:convert';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('fromAsset', () async {
    final attachment = FlutterSentryAttachment.fromAsset(
      'foobar.txt',
      bundle: TestAssetBundle(),
      addToTransactions: true,
    );

    expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
    expect(attachment.contentType, isNull);
    expect(attachment.filename, 'foobar.txt');
    expect(attachment.addToTransactions, true);
    await expectLater(await attachment.bytes, [102, 111, 111, 32, 98, 97, 114]);
  });

  test('invalid Uri fall back to unknown', () async {
    final attachment = FlutterSentryAttachment.fromAsset(
      'htttps://[Filtered].com/foobar.txt',
      bundle: TestAssetBundle(),
      addToTransactions: true,
    );

    expect(attachment.filename, 'unknown');
  });
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'foobar.txt') {
      return ByteData.view(
        Uint8List.fromList(utf8.encode('foo bar')).buffer,
      );
    }

    return ByteData(0);
  }
}
