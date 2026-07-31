import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/access_aware_map.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('$AccessAwareMap', () {
    test('set/get value for key', () {
      final sut = AccessAwareMap({'foo': 'foo'});

      sut['foo'] = 'bar';
      sut['bar'] = 'foo';

      expect(sut['foo'], 'bar');
      expect(sut['bar'], 'foo');
    });

    test('clear', () {
      final sut = AccessAwareMap({'foo': 'foo'});

      sut.clear();

      expect(sut.accessedKeysWithValues.isEmpty, true);
      expect(sut.isEmpty, true);
    });

    test('keys', () {
      final sut = AccessAwareMap({'foo': 'foo', 'bar': 'bar'});
      expect(
        sut.keys.sortedBy((it) => it),
        ['bar', 'foo'].sortedBy((it) => it),
      );
    });

    test('remove', () {
      final sut = AccessAwareMap({'foo': 'foo'});

      sut.remove('foo');

      expect(sut.isEmpty, true);
    });

    group('when tracking access', () {
      test('collects accessedKeys', () {
        final sut = AccessAwareMap({'foo': 'foo', 'bar': 'bar'});

        sut['foo'];
        sut['bar'];
        sut['baz'];

        expect(sut.accessedKeysWithValues, {'foo', 'bar'});
      });

      test('returns notAccessed data', () {
        final sut = AccessAwareMap({'foo': 'foo', 'bar': 'bar'});

        sut['foo'];

        final notAccessed = sut.notAccessed();
        expect(notAccessed, isNotNull);
        expect(notAccessed?.containsKey('foo'), false);
        expect(notAccessed?.containsKey('bar'), true);
      });
    });
  });

  group('JsonReaders', () {
    test(
      'readString on type mismatch returns null and keeps value unaccessed',
      () {
        final sut = AccessAwareMap({'name': 42});

        expect(sut.readString('name'), isNull);
        expect(sut.notAccessed(), {'name': 42});
      },
    );

    test(
      'on type mismatch logs a warning naming key, expected and actual type',
      () {
        final logs = <String>[];
        configureDiagnosticTestLogger(
          onLog: (level, message, {error, stackTrace}) {
            if (level == SentryLevel.warning) logs.add(message);
          },
        );
        addTearDown(resetDiagnosticTestLogger);

        AccessAwareMap({'name': 42}).readString('name');

        expect(logs, hasLength(1));
        expect(logs.single, contains('"name"'));
        expect(logs.single, contains('String'));
        expect(logs.single, contains('int'));
      },
    );

    test('on absent key returns null and reports nothing unaccessed', () {
      final sut = AccessAwareMap(<String, dynamic>{});

      expect(sut.readString('name'), isNull);
      expect(sut.notAccessed(), isNull);
    });

    test('on present null value marks the key accessed', () {
      final sut = AccessAwareMap({'name': null});

      expect(sut.readString('name'), isNull);
      expect(sut.notAccessed(), isNull);
    });

    test('readString returns the string', () {
      expect(AccessAwareMap({'name': 'device'}).readString('name'), 'device');
    });

    test('readDouble converts int to double', () {
      expect(AccessAwareMap({'density': 3}).readDouble('density'), 3.0);
    });

    test('readDouble returns null for a non-numeric value', () {
      expect(AccessAwareMap({'density': 'high'}).readDouble('density'), isNull);
    });

    test('readDouble drops a non-finite value instead of preserving it', () {
      final sut = AccessAwareMap({'density': double.nan});

      expect(sut.readDouble('density'), isNull);
      // Preserving it would make jsonEncode throw and cost the whole event.
      expect(sut.notAccessed(), isNull);
    });

    test('readInt returns the int', () {
      expect(AccessAwareMap({'dpi': 440}).readInt('dpi'), 440);
    });

    test('readInt converts an integral double to int', () {
      expect(AccessAwareMap({'dpi': 440.0}).readInt('dpi'), 440);
    });

    test('readInt returns null for a fractional double and preserves it', () {
      final sut = AccessAwareMap({'dpi': 42.7});

      expect(sut.readInt('dpi'), isNull);
      expect(sut.notAccessed(), {'dpi': 42.7});
    });

    test(
      'readInt returns null for a double beyond exact integer precision',
      () {
        // toInt() would silently clamp this to the maximum int64 value.
        expect(AccessAwareMap({'size': 1e300}).readInt('size'), isNull);
      },
    );

    test('readBool returns the bool', () {
      expect(AccessAwareMap({'online': true}).readBool('online'), isTrue);
    });

    test('readBool converts numeric 0 and 1', () {
      expect(AccessAwareMap({'online': 1}).readBool('online'), isTrue);
      expect(AccessAwareMap({'online': 0}).readBool('online'), isFalse);
      expect(AccessAwareMap({'online': 1.0}).readBool('online'), isTrue);
    });

    test('readBool returns null for other numbers', () {
      expect(AccessAwareMap({'online': 2}).readBool('online'), isNull);
    });

    test('readDateTime parses an ISO-8601 string', () {
      final sut = AccessAwareMap({'boot_time': '2026-07-31T10:20:30.000Z'});

      expect(
        sut.readDateTime('boot_time'),
        DateTime.utc(2026, 7, 31, 10, 20, 30),
      );
    });

    test('readDateTime returns null for an unparsable string', () {
      final sut = AccessAwareMap({'boot_time': 'not a date'});

      expect(sut.readDateTime('boot_time'), isNull);
      expect(sut.notAccessed(), {'boot_time': 'not a date'});
    });

    test('readDateTime returns null for a non-string value', () {
      expect(
        AccessAwareMap({'boot_time': 12345}).readDateTime('boot_time'),
        isNull,
      );
    });

    test('readMap returns the nested object', () {
      final sut = AccessAwareMap({
        'sdk': {'name': 'sentry.dart'},
      });

      expect(sut.readMap('sdk'), {'name': 'sentry.dart'});
    });

    test('readMap converts a map that is not keyed by String', () {
      final sut = AccessAwareMap({
        'sdk': <Object?, Object?>{'name': 'sentry.dart'},
      });

      expect(sut.readMap('sdk'), {'name': 'sentry.dart'});
    });

    test('readMap returns null for a non-map value and preserves it', () {
      final sut = AccessAwareMap({'sdk': 'not-a-map'});

      expect(sut.readMap('sdk'), isNull);
      expect(sut.notAccessed(), {'sdk': 'not-a-map'});
    });

    test('readMap returns null when a key is not a String', () {
      final sut = AccessAwareMap({
        'sdk': <Object?, Object?>{1: 'sentry.dart'},
      });

      expect(sut.readMap('sdk'), isNull);
    });

    test('readStringMap returns the string values', () {
      final sut = AccessAwareMap({
        'tags': {'a': '1', 'b': '2'},
      });

      expect(sut.readStringMap('tags'), {'a': '1', 'b': '2'});
    });

    test('readStringMap drops entries whose value is not a String', () {
      final sut = AccessAwareMap({
        'tags': {'a': '1', 'b': 2},
      });

      expect(sut.readStringMap('tags'), {'a': '1'});
    });

    test('readStringList returns the strings', () {
      final sut = AccessAwareMap({
        'fingerprint': ['a', 'b'],
      });

      expect(sut.readStringList('fingerprint'), ['a', 'b']);
    });

    test('readStringList drops elements that are not Strings', () {
      final sut = AccessAwareMap({
        'fingerprint': ['a', 2, null],
      });

      expect(sut.readStringList('fingerprint'), ['a']);
    });

    test(
      'readStringList returns null for a non-list value and preserves it',
      () {
        final sut = AccessAwareMap({'fingerprint': 'a'});

        expect(sut.readStringList('fingerprint'), isNull);
        expect(sut.notAccessed(), {'fingerprint': 'a'});
      },
    );

    test('readMapList returns the nested objects', () {
      final sut = AccessAwareMap({
        'frames': [
          {'function': 'main'},
          <Object?, Object?>{'function': 'run'},
        ],
      });

      expect(sut.readMapList('frames'), [
        {'function': 'main'},
        {'function': 'run'},
      ]);
    });

    test('readList keeps every element, including nulls', () {
      final sut = AccessAwareMap({
        'params': ['a', 1, null],
      });

      expect(sut.readList('params'), ['a', 1, null]);
    });

    test('readList returns null for a non-list value and preserves it', () {
      final sut = AccessAwareMap({'params': 'a'});

      expect(sut.readList('params'), isNull);
      expect(sut.notAccessed(), {'params': 'a'});
    });

    test('readIntList drops elements that are not ints', () {
      final sut = AccessAwareMap({
        'frames_omitted': [1, 2.0, 'three'],
      });

      expect(sut.readIntList('frames_omitted'), [1, 2]);
    });

    test('readObject builds the child from the nested object', () {
      final sut = AccessAwareMap({
        'sdk': {'name': 'sentry.dart'},
      });

      expect(sut.readObject('sdk', (json) => json['name']), 'sentry.dart');
    });

    test('readObject returns null for a non-map value and preserves it', () {
      final sut = AccessAwareMap({'sdk': 'not-a-map'});

      expect(sut.readObject('sdk', (json) => json['name']), isNull);
      expect(sut.notAccessed(), {'sdk': 'not-a-map'});
    });

    test(
      'readDouble outside the allowed range returns null and preserves it',
      () {
        final sut = AccessAwareMap({'battery_level': 150.0});

        expect(sut.readDouble('battery_level', min: 0, max: 100), isNull);
        expect(sut.notAccessed(), {'battery_level': 150.0});
      },
    );

    test(
      'readObject drops a child it cannot build and keeps the raw value',
      () {
        final sut = AccessAwareMap({
          'sdk': {'name': 'sentry.dart'},
        });

        expect(
          sut.readObject<String>('sdk', (json) => throw StateError('boom')),
          isNull,
        );
        expect(sut.notAccessed(), {
          'sdk': {'name': 'sentry.dart'},
        });
      },
    );

    test('readObjectList drops only the child it cannot build', () {
      final sut = AccessAwareMap({
        'frames': [
          {'function': 'main'},
          {'function': 'bad'},
        ],
      });

      final result = sut.readObjectList('frames', (json) {
        if (json['function'] == 'bad') throw StateError('boom');
        return json['function'] as String;
      });

      expect(result, ['main']);
    });

    test('readObjectList builds the children', () {
      final sut = AccessAwareMap({
        'frames': [
          {'function': 'main'},
          {'function': 'run'},
        ],
      });

      expect(sut.readObjectList('frames', (json) => json['function']), [
        'main',
        'run',
      ]);
    });

    test('readMapList drops elements that are not maps', () {
      final sut = AccessAwareMap({
        'frames': [
          {'function': 'main'},
          'oops',
        ],
      });

      expect(sut.readMapList('frames'), [
        {'function': 'main'},
      ]);
    });
  });
}
