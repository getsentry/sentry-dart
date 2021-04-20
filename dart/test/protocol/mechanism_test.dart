import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

// TODO(denis)

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      type: 'type1',
      description: 'description1',
      helpLink: 'helpLink1',
      handled: false,
      synthetic: false,
      meta: {'key1': 'value1'},
      data: {'keyb1': 'valueb1'},
    );

    expect('type1', copy.type);
    expect('description1', copy.description);
    expect('helpLink1', copy.helpLink);
    expect(false, copy.handled);
    expect(false, copy.synthetic);
    expect({'key1': 'value1'}, copy.meta);
    expect({'keyb1': 'valueb1'}, copy.data);
  });
}

Mechanism _generate() => Mechanism(
      type: 'type',
      description: 'description',
      helpLink: 'helpLink',
      handled: true,
      synthetic: true,
      meta: {'key': 'value'},
      data: {'keyb': 'valueb'},
    );
