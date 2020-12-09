import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final frames = [SentryStackFrame(absPath: 'abs1')];
    final registers = {'key1': 'value1'};

    final copy = data.copyWith(
      frames: frames,
      registers: registers,
    );

    expect(
      ListEquality().equals(frames, copy.frames),
      true,
    );
    expect(
      MapEquality().equals(registers, copy.registers),
      true,
    );
  });
}

SentryStackTrace _generate() => SentryStackTrace(
      frames: [SentryStackFrame(absPath: 'abs')],
      registers: {'key': 'value'},
    );
