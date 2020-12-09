import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      type: 'type1',
      imageAddr: 'imageAddr1',
      debugId: 'debugId1',
      debugFile: 'debugFile1',
      imageSize: 2,
      uuid: 'uuid1',
      codeFile: 'codeFile1',
      arch: 'arch1',
      codeId: 'codeId1',
    );

    expect('type1', copy.type);
    expect('imageAddr1', copy.imageAddr);
    expect('debugId1', copy.debugId);
    expect('debugFile1', copy.debugFile);
    expect(2, copy.imageSize);
    expect('uuid1', copy.uuid);
    expect('codeFile1', copy.codeFile);
    expect('arch1', copy.arch);
    expect('codeId1', copy.codeId);
  });
}

DebugImage _generate() => DebugImage(
      type: 'type',
      imageAddr: 'imageAddr',
      debugId: 'debugId',
      debugFile: 'debugFile',
      imageSize: 1,
      uuid: 'uuid',
      codeFile: 'codeFile',
      arch: 'arch',
      codeId: 'codeId',
    );
