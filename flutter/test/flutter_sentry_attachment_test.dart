import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('fromAsset', () async {
    final attachment = FlutterSentryAttachment.fromAsset(
      'foobar.txt',
      bundle: TestAssetBundle(),
    );

    expect(attachment.attachmentType, SentryAttachment.typeAttachmentDefault);
    expect(attachment.contentType, isNull);
    expect(attachment.filename, 'foobar.txt');
    await expectLater(await attachment.bytes, [102, 111, 111, 32, 98, 97, 114]);
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
