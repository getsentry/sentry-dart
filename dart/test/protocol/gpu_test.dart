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
      name: 'name1',
      id: 11,
      vendorId: 22,
      vendorName: 'vendorName1',
      memorySize: 33,
      apiType: 'apiType1',
      multiThreadedRendering: false,
      version: 'version1',
      npotSupport: 'npotSupport1',
    );

    expect('name1', copy.name);
    expect(11, copy.id);
    expect(22, copy.vendorId);
    expect('vendorName1', copy.vendorName);
    expect(33, copy.memorySize);
    expect('apiType1', copy.apiType);
    expect(false, copy.multiThreadedRendering);
    expect('version1', copy.version);
    expect('npotSupport1', copy.npotSupport);
  });
}

SentryGpu _generate() => SentryGpu(
      name: 'name',
      id: 1,
      vendorId: 2,
      vendorName: 'vendorName',
      memorySize: 3,
      apiType: 'apiType',
      multiThreadedRendering: true,
      version: 'version',
      npotSupport: 'npotSupport',
    );
