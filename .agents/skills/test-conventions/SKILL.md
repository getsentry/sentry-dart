---
name: test-conventions
description: Enforce Sentry Dart/Flutter SDK test conventions for naming, structure, and fixtures. Use when writing tests, adding tests, modifying tests, reviewing test code, fixing failing tests, adding test coverage, TDD, reproducing bugs with tests, regression tests, or test refactoring in any package in this Melos monorepo.
---

Apply these conventions to all new and modified tests across every package in this monorepo. Existing tests may not follow these conventions — do not refactor them unless asked.

## File Structure

- One test file per source file. Mirror the source path: `lib/src/hub.dart` → `test/hub_test.dart`.
- Every test file has a single `void main() { ... }` entry point.
- Use a single top-level `group()` matching the class or unit name as a plain string.

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

### One-line check

If it doesn't read like a sentence, rename the groups:

```dart
// "Hub returns the scope" (1 group)
group('Hub', () {
  test('returns the scope', () { });
});

// "Hub when capturing sends event to transport" (2 groups)
group('Hub', () {
  group('when capturing', () {
    test('sends event to transport', () { });
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
group('Client', () {
  group('when disabled', () {
    test('does not send events', () { });
    test('returns null for captureEvent', () { });
  });
});
```

## Fixture Pattern

Define a `Fixture` class at the bottom of each test file to encapsulate setup:

```dart
class Fixture {
  final transport = MockTransport();
  final options = defaultTestOptions();

  SentryClient getSut({bool attachStacktrace = true}) {
    options.attachStacktrace = attachStacktrace;
    options.transport = transport;
    return SentryClient(options);
  }
}
```

Rules:
- Place `Fixture` at the bottom of the test file.
- Use `getSut()` to create the System Under Test with configurable options.
- Initialize the fixture in `setUp()` for each test group.
- When setup steps are shared, use the top-most shared group to set up the fixture.

## Test Options

Always use `defaultTestOptions()` from `test_utils.dart` to create options — never construct `SentryOptions` directly in tests.

## Setup and Teardown

- Place `setUp()` / `tearDown()` inside the narrowest group they apply to.
- Prefer `late` variables initialized in `setUp()` over inline construction in each test.
- Use `setUpAll()` / `tearDownAll()` only for genuinely expensive shared resources.

## Assertions

- Use `expect()` with matchers from `package:test`.
- Prefer specific matchers (`throwsArgumentError`, `isA<SentryException>()`) over generic ones (`throwsException`, `isA<Exception>()`).
- One logical assertion per test. Multiple `expect()` calls are fine if they verify a single behavior.

## Async

- Return the `Future` or mark the test callback as `async`. Never fire-and-forget.
- Use `expectLater` with stream matchers (`emitsInOrder`, `emitsError`) for stream assertions.
- Use `fakeAsync` for timer and microtask-dependent code.

## Mocking

- **Prefer fakes over mocks.** Fakes are hand-written implementations that capture state, making tests resilient to refactoring and readable as documentation. Use them as the default for test doubles.
- Only reach for mocks when faking is impractical, e.g. a large
  third-party interface where writing a full fake isn't worth the effort.
- Use test doubles already defined in the project.
- When creating a new fake, implement the interface directly and keep it minimal — only the methods the tests actually exercise.

## General

- Keep tests deterministic. No reliance on real clocks, network, or filesystem unless writing an integration test.
- Do not duplicate test utilities. If you need test utilities across different packages then add them to `packages/_sentry_testing`