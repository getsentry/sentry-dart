import 'package:sentry/src/protocol/access_aware_map.dart';
import 'package:test/test.dart';

void main() {
  group('access aware', () {
    test('collects accessedKeys', () {
      final sut = AccessAwareMap({
        'foo': 'foo',
        'bar': 'bar',
      });

      sut['foo'];
      sut['bar'];
      sut['baz'];

      expect(sut.accessedKeys, {'foo', 'bar', 'baz'});
    });

    test('returns notAccessed data', () {
      final sut = AccessAwareMap({
        'foo': 'foo',
        'bar': 'bar',
      });

      sut['foo'];

      final notAccessed = sut.notAccessed();
      expect(notAccessed, isNotNull);
      expect(notAccessed?.containsKey('foo'), false);
      expect(notAccessed?.containsKey('bar'), true);
    });
  });

  group('map base functionality', () {
    test('set value with []= operator', () {
      final sut = AccessAwareMap({
        'foo': 'foo',
      });

      sut['foo'] = 'bar';
      sut['bar'] = 'foo';

      expect(sut['foo'], 'bar');
      expect(sut['bar'], 'foo');
    });

    test('clear', () {
      final sut = AccessAwareMap({
        'foo': 'foo',
      });

      sut.clear();

      expect(sut.accessedKeys.isEmpty, true);
      expect(sut.isEmpty, true);
    });

    test('keys', () {
      final sut = AccessAwareMap({
        'foo': 'foo',
        'bar': 'bar',
      });
      expect(sut.keys.toSet(), {'foo', 'bar'});
    });

    test('remove', () {
      final sut = AccessAwareMap({'foo': 'foo'});

      sut.remove('foo');

      expect(sut['foo'], isNull);
    });
  });
}
