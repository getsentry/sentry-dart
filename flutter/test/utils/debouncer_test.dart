import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/utils/debouncer.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('Debouncer should not debounce on the first check per default', () {
    final sut = fixture.getSut();
    expect(sut.shouldDebounce(), isFalse);
  });

  test('Debouncer should debounce on the first check', () {
    final sut = fixture.getSut(debounceOnFirstTry: true);
    expect(sut.shouldDebounce(), isTrue);
  });

  test('Debouncer should not debounce if wait time is 0', () {
    final sut = fixture.getSut(waitTimeMs: 0);
    expect(sut.shouldDebounce(), isFalse);
    expect(sut.shouldDebounce(), isFalse);
    expect(sut.shouldDebounce(), isFalse);
  });

  test('Debouncer should signal debounce if the second invocation is too early',
      () {
    fixture.currentTimeMs = 1000;
    final sut = fixture.getSut(waitTimeMs: 3000);
    expect(sut.shouldDebounce(), isFalse);

    fixture.currentTimeMs = 3999;
    expect(sut.shouldDebounce(), isTrue);
  });

  test(
      'Debouncer should not signal debounce if the second invocation is late enough',
      () {
    fixture.currentTimeMs = 1000;
    final sut = fixture.getSut(waitTimeMs: 3000);
    expect(sut.shouldDebounce(), isFalse);

    fixture.currentTimeMs = 4000;
    expect(sut.shouldDebounce(), isFalse);
  });
}

class Fixture {
  int currentTimeMs = 0;

  DateTime mockClock() => DateTime.fromMillisecondsSinceEpoch(currentTimeMs);

  Debouncer getSut({int waitTimeMs = 3000, bool debounceOnFirstTry = false}) {
    return Debouncer(mockClock,
        waitTimeMs: waitTimeMs, debounceOnFirstTry: debounceOnFirstTry);
  }
}
