import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/utils/debouncer.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('Debouncer should not debounce on the first check per default', () {
    final debouncer = fixture.getDebouncer();
    expect(debouncer.shouldDebounce(), isFalse);
  });

  test('Debouncer should debounce on the first check', () {
    final debouncer = fixture.getDebouncer(debounceOnFirstTry: true);
    expect(debouncer.shouldDebounce(), isTrue);
  });

  test('Debouncer should not debounce if wait time is 0', () {
    final debouncer = fixture.getDebouncer(waitTimeMs: 0);
    expect(debouncer.shouldDebounce(), isFalse);
    expect(debouncer.shouldDebounce(), isFalse);
    expect(debouncer.shouldDebounce(), isFalse);
  });

  test('Debouncer should signal debounce if the second invocation is too early',
      () {
    fixture.currentTimeMs = 1000;
    final debouncer = fixture.getDebouncer(waitTimeMs: 3000);
    expect(debouncer.shouldDebounce(), isFalse);

    fixture.currentTimeMs = 3999;
    expect(debouncer.shouldDebounce(), isTrue);
  });

  test(
      'Debouncer should not signal debounce if the second invocation is late enough',
      () {
    fixture.currentTimeMs = 1000;
    final debouncer = fixture.getDebouncer(waitTimeMs: 3000);
    expect(debouncer.shouldDebounce(), isFalse);

    fixture.currentTimeMs = 4000;
    expect(debouncer.shouldDebounce(), isFalse);
  });
}

class Fixture {
  int currentTimeMs = 0;

  DateTime mockClock() => DateTime.fromMillisecondsSinceEpoch(currentTimeMs);

  Debouncer getDebouncer(
      {int waitTimeMs = 3000, bool debounceOnFirstTry = false}) {
    return Debouncer(mockClock,
        waitTimeMs: waitTimeMs, debounceOnFirstTry: debounceOnFirstTry);
  }
}
