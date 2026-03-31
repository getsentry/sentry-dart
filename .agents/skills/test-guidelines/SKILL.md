---
name: test-guidelines
description: Enforce Sentry Dart/Flutter SDK test conventions for naming, structure, and fixtures. Use when writing tests, adding tests, modifying tests, reviewing test code, fixing failing tests, adding test coverage, TDD, reproducing bugs with tests, regression tests, or test refactoring in any package in this Melos monorepo.
---

Apply these conventions to all new and modified tests across every package in this monorepo. Existing tests may not follow these conventions — do not refactor them unless asked.

## File Structure

- One test file per source file. Mirror the source path: `lib/src/hub.dart` → `test/hub_test.dart`.
- Every test file has a single `void main() { ... }` entry point.
- Use a single top-level `group()` matching the class or unit name as a plain string.

```dart
// GOOD: Mirrors source path, single main, single top-level group
// test/sentry_client_test.dart (for lib/src/sentry_client.dart)
void main() {
  group('SentryClient', () {
    // all tests here
  });
}

// AVOID: Multiple top-level groups or no group wrapper
void main() {
  group('SentryClient capture', () { });
  group('SentryClient close', () { });
}
```

## Test Naming

Nested `group()` + `test()` names MUST read as a sentence when concatenated.

Pattern: `[Subject] [Context] [Variant] [Behavior]`

| Depth | Role | Style | Example |
|-------|------|-------|---------|
| Group 1 | Subject | Noun | `Client` |
| Group 2 | Context | `when` / `in` / `during` | `when connected` |
| Group 3 | Variant | `with` / `given` / `using` | `with valid input` |
| Test | Behavior | Verb phrase | `sends message` |

### Style rules

- Use plain verb phrases: `returns scope`, `throws ArgumentError`, `sends event to transport`.
- Do not prefix test names with `should` — prefer direct phrasing.
- Use string descriptions for group names. Do not pass Type literals (e.g. `group(Hub, ...)` is not allowed).

```dart
// GOOD: Plain verb phrase, string group name
group('Hub', () {
  test('returns the scope', () { });
});

// AVOID: "should" prefix, Type literal as group name
group(Hub, () {
  test('should return the scope', () { });
});
```

### One-line check

If it doesn't read like a sentence, rename the groups:

```dart
// GOOD: "Hub returns the scope" reads as a sentence
group('Hub', () {
  test('returns the scope', () { });
});

// GOOD: "Hub when capturing sends event to transport"
group('Hub', () {
  group('when capturing', () {
    test('sends event to transport', () { });
  });
});

// AVOID: Doesn't read as a sentence ("Hub capture test event sent")
group('Hub', () {
  group('capture test', () {
    test('event sent', () { });
  });
});
```

## Depth Rules

- **Maximum depth: 3 groups.** More nesting is a code smell — suggest refactoring the implementation.
- Fold simple variants into the test name instead of adding a group. Use a group only when multiple tests share the same variant setup.

```dart
// GOOD: Simple variant in test name (2 groups + test)
group('Hub', () {
  group('when bound to client', () {
    test('with valid DSN initializes correctly', () { });
    test('with empty DSN throws ArgumentError', () { });
  });
});

// AVOID: Unnecessary nesting (3 groups + test)
group('Hub', () {
  group('when bound to client', () {
    group('with valid DSN', () {
      test('initializes correctly', () { });
    });
  });
});
```

## Negative Tests

Use clear verb phrases indicating absence or failure:

| Pattern | When | Example |
|---------|------|---------|
| `does not <verb>` | Behavior intentionally skipped | `does not send event` |
| `throws <ExceptionType>` | Expecting an exception | `throws ArgumentError` |
| `returns null` | Null result expected | `returns null when missing` |
| `ignores <thing>` | Input deliberately ignored | `ignores empty breadcrumbs` |

```dart
// GOOD: Clear verb phrases indicating absence or failure
group('Client', () {
  group('when disabled', () {
    test('does not send events', () { });
    test('returns null for captureEvent', () { });
    test('throws StateError', () { });
  });
});

// AVOID: Vague negations or "should not" phrasing
group('Client', () {
  group('when disabled', () {
    test('should not work', () { });
    test('fails', () { });
    test('no events', () { });
  });
});
```

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
group('Client', () {
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
group('Client', () {
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

## Assertions

- Use `expect()` with matchers from `package:test`.
- Prefer specific matchers (`throwsArgumentError`, `isA<SentryException>()`) over generic ones (`throwsException`, `isA<Exception>()`).
- One logical assertion per test. Multiple `expect()` calls are fine if they verify a single behavior.

```dart
// GOOD: Specific matchers, single logical assertion
test('captures exception with stacktrace', () {
  expect(event.exceptions, hasLength(1));
  expect(event.exceptions!.first, isA<SentryException>());
  expect(event.exceptions!.first.stackTrace, isNotNull);
});

// AVOID: Generic matchers, testing unrelated behaviors
test('captures exception', () {
  expect(event.exceptions, isNotNull); // too vague
  expect(event.exceptions!.first, isA<Object>()); // too generic
  expect(event.breadcrumbs, isEmpty); // unrelated assertion
});
```

## Async

- Return the `Future` or mark the test callback as `async`. Never fire-and-forget.
- Use `expectLater` with stream matchers (`emitsInOrder`, `emitsError`) for stream assertions.
- Use `fakeAsync` for timer and microtask-dependent code.

```dart
// GOOD: async test, awaited future
test('sends event asynchronously', () async {
  await sut.captureEvent(event);
  expect(fixture.transport.events, hasLength(1));
});

// GOOD: fakeAsync for timer-dependent code
test('flushes after timeout', () {
  fakeAsync((async) {
    sut.startTimer();
    async.elapse(Duration(seconds: 5));
    expect(fixture.transport.flushed, isTrue);
  });
});

// AVOID: Fire-and-forget future
test('sends event', () {
  sut.captureEvent(event); // missing await!
  expect(fixture.transport.events, hasLength(1));
});
```

## Mocking

- **Prefer fakes over mocks.** Fakes are hand-written implementations that capture state, making tests resilient to refactoring and readable as documentation. Use them as the default for test doubles.
- Only reach for mocks when faking is impractical, e.g. a large
  third-party interface where writing a full fake isn't worth the effort.
- Use test doubles already defined in the project.
- When creating a new fake, implement the interface directly and keep it minimal — only the methods the tests actually exercise.
- Existing mocks are typically found in `mocks.dart` files.

```dart
// GOOD: Hand-written fake that captures state
class FakeTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId ?? SentryId.empty();
  }
}

// AVOID: Mock with verification-heavy assertions
final transport = MockTransport();
when(transport.send(any)).thenAnswer((_) async => SentryId.newId());
// ... later
verify(transport.send(any)).called(1);
```

## General

- Keep tests deterministic. No reliance on real clocks, network, or filesystem unless writing an integration test.
- Do not duplicate test utilities. If you need test utilities across different packages then add them to `packages/_sentry_testing`

```dart
// GOOD: Deterministic clock
final clock = DateTime.utc(2024, 1, 15, 12, 0, 0);
options.clock = () => clock;

// AVOID: Real clock — flaky on slow CI
final now = DateTime.now();
expect(event.timestamp!.difference(now).inSeconds, lessThan(1));
```

## Integration / E2E Tests

- Integration tests live in `packages/flutter/example/integration_test`.
- JNI and FFI bindings cannot be mocked or faked — integration tests are required when working with native interop.
- Prefer integration tests for any behavior that depends on native platform APIs.
