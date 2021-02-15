import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    // MapEquality fails for some reason, it probably check the instances equality too
    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final newSdkInfo = SdkInfo(
      sdkName: 'sdkName1',
    );
    final newImageList = [DebugImage(type: 'macho', uuid: 'uuid1')];

    final copy = data.copyWith(
      sdk: newSdkInfo,
      images: newImageList,
    );

    expect(
      ListEquality().equals(newImageList, copy.images),
      true,
    );
    expect(
      MapEquality().equals(newSdkInfo.toJson(), copy.sdk!.toJson()),
      true,
    );
  });
}

DebugMeta _generate() => DebugMeta(
      sdk: SdkInfo(
        sdkName: 'sdkName',
      ),
      images: [DebugImage(type: 'macho', uuid: 'uuid')],
    );
