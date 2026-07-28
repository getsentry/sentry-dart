# Fixtures, Test Options, Setup & Teardown

The full rules behind the one-line summary in [SKILL.md](../SKILL.md). All of these concern how a test assembles and resets its System Under Test.

## Fixture Pattern

Define a `Fixture` class at the bottom of each test file to encapsulate setup:

```dart
// GOOD: Fixture class with getSut() and configurable options
class Fixture {
  final transport = MockTransport();
  final options = defaultTestOptions();

  SentryClient getSut({bool attachStacktrace = true}) {
    options.attachStacktrace = attachStacktrace;
    options.transport = transport;
    return SentryClient(options);
  }
}

// Usage in tests:
late Fixture fixture;

setUp(() {
  fixture = Fixture();
});

test('captures event', () {
  final sut = fixture.getSut();
  // ...
});
```

```dart
// AVOID: Inline setup without Fixture, duplicated across tests
test('captures event', () {
  final options = SentryOptions(dsn: fakeDsn);
  final transport = MockTransport();
  options.transport = transport;
  final client = SentryClient(options);
  // ...
});
```

Rules:
- Place `Fixture` at the bottom of the test file.
- Use `getSut()` to create the System Under Test with configurable options.
- Initialize the fixture in `setUp()` for each test group.
- When setup steps are shared, use the top-most shared group to set up the fixture.

## Test Options

Always use `defaultTestOptions()` from `test_utils.dart` to create options — never construct `SentryOptions` directly in tests.

```dart
// GOOD: Use defaultTestOptions()
final options = defaultTestOptions();
options.dsn = fakeDsn;

// AVOID: Constructing SentryOptions directly
final options = SentryOptions(dsn: fakeDsn);
```

## Setup and Teardown

- Place `setUp()` / `tearDown()` inside the narrowest group they apply to.
- Prefer `late` variables initialized in `setUp()` over inline construction in each test.
- Use `setUpAll()` / `tearDownAll()` only for genuinely expensive shared resources.

```dart
// GOOD: late + setUp in narrowest group, fixture reset per test
group('$Client', () {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();
  });

  group('when capturing', () {
    test('sends event to transport', () {
      final sut = fixture.getSut();
      // ...
    });
  });
});

// AVOID: setUp at top level when only one group needs it
group('$Client', () {
  late Fixture fixture;
  late SomeExpensiveResource resource;

  // Wrong: setUpAll for cheap objects
  setUpAll(() {
    fixture = Fixture();
    resource = SomeExpensiveResource();
  });

  // Wrong: setUp in a deeper group when all sibling groups share it
  group('when capturing', () {
    setUp(() { fixture = Fixture(); });
    test('sends event', () { });
  });
  group('when closing', () {
    setUp(() { fixture = Fixture(); }); // duplicated
    test('flushes transport', () { });
  });
});
```
