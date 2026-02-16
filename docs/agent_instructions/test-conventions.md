# Test Conventions

> **Note:** Existing tests may not follow these conventions. New and modified tests should adhere to these guidelines.

## Structure

**Rule:** Nested `group()` + `test()` names must read as a sentence when concatenated.

Pattern: `[Subject] [Context] [Variant] [Behavior]`

- Subject = noun (e.g., `Client`)
- Context = preposition phrase (e.g., `when connected`)
- Variant = condition (e.g., `with valid input`)
- Behavior = verb phrase (e.g., `sends message`)

## Naming by Depth

- Group 1 (Subject) - use Noun style - example: `Client`
- Group 2 (Context) - use `when / in / during` style - example: `when connected`
- Group 3 (Variant) - use `with / given / using` style - example: `with valid input`
- Test (Behavior) - use Verb phrase style - example: `sends message`

## Depth Guidelines

- **Maximum depth: 3 groups.** If you need more nesting, call out that this is a code smell and suggest refactoring the implementation.
- **Simple variants can go in the test name** instead of a separate group. Use a group only when multiple tests share the same variant setup.

```dart
// ✅ Good: Simple variant in test name (2 groups + test)
group('Hub', () {
  group('when bound to client', () {
    test('with valid DSN initializes correctly', () { });
    test('with empty DSN throws exception', () { });
  });
});

// ❌ Avoid: Unnecessary nesting for simple variants (3 groups + test)
group('Hub', () {
  group('when bound to client', () {
    group('with valid DSN', () {
      test('initializes correctly', () { });
    });
  });
});
```

## Negative Tests

Use clear verb phrases that indicate the absence of behavior or expected failures:

- `does not <verb>` - when behavior is intentionally skipped - example: `does not send event`
- `throws <ExceptionType>` - when expecting an exception - example: `throws ArgumentError`
- `returns null` - when null result is expected - example: `returns null when missing`
- `ignores <thing>` - when input is deliberately ignored - example: `ignores empty breadcrumbs`

```dart
group('Client', () {
  group('when disabled', () {
    test('does not send events', () { });
    test('returns null for captureEvent', () { });
  });
});
```

## One-Line Check

**If it doesn't read like a sentence, rename the groups.**

```dart
// Subject → Behavior (1 group)
group('Hub', () {
  test('returns the scope', () { });
});
// Reads: "Hub returns the scope"

// Subject → Context → Behavior (2 groups)
group('Hub', () {
  group('when capturing', () {
    test('sends event to transport', () { });
    test('attaches breadcrumbs', () { });
  });
});
// Reads: "Hub when capturing sends event to transport"
```

## Fixture Pattern

Use a `Fixture` class at the end of test files to encapsulate test setup:

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

- Define `Fixture` at the bottom of each test file
- Use `getSut()` method to create the System Under Test with configurable options
- Initialize fixture in `setUp()` for each test group; when setup steps are shared use the top-most shared group to set up the fixture

## Test Options

Always use `defaultTestOptions()` from `test_utils.dart` to create options
