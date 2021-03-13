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
      formatted: 'message 21',
      template: 'message 2 %d',
      params: ['2'],
    );

    expect('message 21', copy.formatted);
    expect('message 2 %d', copy.template);
    expect(['2'], copy.params);
  });
}

SentryMessage _generate() => SentryMessage(
      'message 1',
      template: 'message %d',
      params: ['1'],
    );
