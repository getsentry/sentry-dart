---
name: test-guidelines
description: Enforce Sentry Dart/Flutter SDK test conventions for naming, structure, and fixtures. Use when writing tests, adding tests, modifying tests, reviewing test code, fixing failing tests, adding test coverage, TDD, test-first / red-green, reproducing bugs with tests, regression tests, or test refactoring in any package in this Melos monorepo.
---

Apply these conventions to all new and modified tests across every package in this monorepo. Existing tests may not follow these conventions — do not refactor them unless asked.

Tests are easiest to write against code designed to accept its dependencies — when implementing the code under test, load **design-first** (where the seams go) and **code-guidelines** (the rules).

## Test-First Loop

Work in **vertical slices**, not horizontal ones. One failing test → the minimal code that makes it pass → repeat. Each test is a **tracer bullet**: it proves one thin path end-to-end, and what you learn from it shapes the next.

Do **not** write all the tests first and then all the implementation. That **horizontal slicing** produces tests of *imagined* behavior — they assert the shape you guessed at, pass when the real behavior breaks, and commit you to a structure before you understand it. Write one test at a time, against behavior you can already reason about.

Fixing a bug? Reproduce it with a failing test first — see **diagnosing-bugs** for the loop.

## File Structure

- One test file per source file. Mirror the source path: `lib/src/hub.dart` → `test/hub_test.dart`.
- Every test file has a single `void main() { ... }` entry point.
- Use a single top-level `group()` matching the class or unit name. When the subject is a class or enum, write it with `$` interpolation (`'$SentryClient'`) so the name tracks renames; for other units (top-level functions, extensions) use a plain string — see Style rules.

```dart
// GOOD: Mirrors source path, single main, single top-level group
// test/sentry_client_test.dart (for lib/src/sentry_client.dart)
void main() {
  group('$SentryClient', () {
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
- For a class or enum subject group, use `$` interpolation in the string (`group('$Hub', ...)`) so a rename updates the test name. Never pass a bare Type literal — `group(Hub, ...)` is not allowed.
- Interpolation only works for classes and enums. Extensions and top-level functions cannot be interpolated (`'$MyExtension'` is a compile error; `'$myFunction'` yields a closure string) — use a plain descriptive string there.

```dart
// GOOD: Interpolated class subject, plain verb phrase
group('$Hub', () {
  test('returns the scope', () { });
});

// AVOID: "should" prefix, bare Type literal as group name
group(Hub, () {
  test('should return the scope', () { });
});
```

### One-line check

If it doesn't read like a sentence, rename the groups:

```dart
// GOOD: "Hub returns the scope" reads as a sentence
group('$Hub', () {
  test('returns the scope', () { });
});

// GOOD: "Hub when capturing sends event to transport"
group('$Hub', () {
  group('when capturing', () {
    test('sends event to transport', () { });
  });
});

// AVOID: Doesn't read as a sentence ("Hub capture test event sent")
group('$Hub', () {
  group('capture test', () {
    test('event sent', () { });
  });
});
```

## Depth Rules

- **Maximum depth: 3 groups.** More nesting is a code smell — suggest refactoring the implementation.
- Fold simple variants into the test name instead of adding a group. Use a group only when multiple tests share the same variant setup.
- Drop a group whose context applies to *every* sibling test — it adds depth without discriminating. Move the context into the parent group name or the test names instead.

```dart
// GOOD: Simple variant in test name (2 groups + test)
group('$Hub', () {
  group('when bound to client', () {
    test('with valid DSN initializes correctly', () { });
    test('with empty DSN throws ArgumentError', () { });
  });
});

// AVOID: Unnecessary nesting (3 groups + test)
group('$Hub', () {
  group('when bound to client', () {
    group('with valid DSN', () {
      test('initializes correctly', () { });
    });
  });
});
```

```dart
// GOOD: Behavior carries the context; no redundant wrapper
group('$SentryAttribute', () {
  test('string serializes value with string type', () { });
  test('int serializes value with integer type', () { });
});

// AVOID: Wrapper context true of every test — pure noise
group('$SentryAttribute', () {
  group('when serializing to JSON', () {            // every test serializes
    test('string serializes value with string type', () { });
    test('int serializes value with integer type', () { });
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
group('$Client', () {
  group('when disabled', () {
    test('does not send events', () { });
    test('returns null for captureEvent', () { });
    test('throws StateError', () { });
  });
});

// AVOID: Vague negations or "should not" phrasing
group('$Client', () {
  group('when disabled', () {
    test('should not work', () { });
    test('fails', () { });
    test('no events', () { });
  });
});
```

## Fixtures and Setup

Encapsulate setup in a `Fixture` class at the bottom of each test file, exposing a `getSut()` that builds the System Under Test with configurable, injectable dependencies. Initialize it in `setUp()` within the narrowest group that needs it. Always build options via `defaultTestOptions()` from `test_utils.dart` — never construct `SentryOptions` directly.

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

Full rules — `Fixture` placement, `setUp`/`tearDown` scoping, `setUpAll` caveats, and the `defaultTestOptions()` rule — in [references/fixtures.md](references/fixtures.md).

## What to Test

Test the behavior owned by your change.

Prefer tests that would fail if your change's intended contract were broken: user-visible behavior, public API behavior, meaningful branching logic, data transformations, integration wiring, precedence rules, error handling, and regressions your change could realistically introduce.

Avoid tests that merely re-prove guarantees owned somewhere else, such as a shared helper, base class, framework, serializer, collection type, generated model, or value object that already has focused coverage. A caller test should not exist just to show that its dependencies still work.

Before adding a test, ask:

- What behavior would fail if my change were wrong?
- Is this contract owned by this code, or by something it delegates to?
- Would this test catch a plausible regression in this change?
- Is this asserting an outcome, or just mirroring implementation details?

Do test delegated behavior when the delegation is load-bearing for your change's own contract. For example, preserving user input, choosing precedence between sources, wiring the correct helper, enforcing a public API promise, or covering a past regression can all deserve caller-level tests even if a helper implements part of the behavior.

Good tests make the intended contract harder to break. Noisy tests make refactors harder without improving confidence.

```dart
// GOOD: asserts the new behavior this code path introduces
test('adds sentry.trace_lifecycle stream attribute', () async {
  final span = fixture.createRecordingSpan();
  await fixture.pipeline.captureSpan(span, scope: fixture.scope);
  expect(span.attributes[SemanticAttributesConstants.sentryTraceLifecycle]?.value, 'stream');
});

// AVOID in this feature's tests: re-proves that SentryAttribute.string
// stores its value, which is the value object's own contract
test('SentryAttribute.string stores its value', () {
  final attribute = SentryAttribute.string('value');
  expect(attribute.value, 'value');
});
```

## Assertions

- Use `expect()` with matchers from `package:test`.
- Prefer specific matchers (`throwsArgumentError`, `isA<SentryException>()`) over generic ones (`throwsException`, `isA<Exception>()`).
- One logical assertion per test. Multiple `expect()` calls are fine if they verify a single behavior.
- **Avoid the tautological test.** Assert the literal expected value, not the same constant the production code uses to produce it — a test whose expected value is computed the way the code computes it passes by construction and can never disagree with the code. Sharing one constant across production and test makes the assertion tautological: it still passes if the constant holds the wrong value. Using the constant as the lookup *key* is fine; pin the expected *value* as a literal.

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

```dart
// GOOD: pin the expected value as a literal
expect(span.data[SentryDatabase.dbSystemKey], 'sqlite');

// AVOID (tautological): asserting against the same constant the production code uses to set it
expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
```

## Mocking

**Prefer fakes over mocks** — hand-written implementations that capture state, resilient to refactoring and readable as documentation. Reach for a mock only when faking a large third-party interface isn't worth it. A test that's hard to fake usually signals the code under test should accept its dependencies rather than construct them (a **design-first** concern).

Full guidance, including **designing for mockability** (dependency injection, SDK-style interfaces, mocking only at real boundaries), in [references/mocking.md](references/mocking.md).

## Async

Never fire-and-forget: return the `Future` or mark the callback `async`. Use `expectLater` with stream matchers for streams, and `fakeAsync` for timer/microtask-dependent code. Examples in [references/async.md](references/async.md).

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
