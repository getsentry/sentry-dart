# Sentry Development Guide for AI Agents

## Overview

Sentry is a developer-first error tracking and performance monitoring platform.
This repository contains the Sentry Dart/Flutter SDK and integrations with third party libraries.

## Project Structure

| Directory / File                   | Description                                       |
| ---------------------------------- | ------------------------------------------------- |
| **packages/**                      | SDK packages (Melos monorepo)                     |
| `packages/dart/`                   | Core Sentry Dart SDK                              |
| `packages/flutter/`                | Sentry Flutter SDK (includes native integrations) |
| `packages/dio/`                    | Dio HTTP client integration                       |
| `packages/drift/`                  | Drift database integration                        |
| `packages/file/`                   | File I/O integration                              |
| `packages/hive/`                   | Hive database integration                         |
| `packages/isar/`                   | Isar database integration                         |
| `packages/sqflite/`                | SQLite integration                                |
| `packages/logging/`                | Dart logging package integration                  |
| `packages/supabase/`               | Supabase integration                              |
| `packages/firebase_remote_config/` | Firebase Remote Config integration                |
| `packages/link/`                   | Deep linking integration                          |
| **docs/**                          | Documentation and release checklists              |
| **e2e_test/**                      | End-to-end test suite                             |
| **min_version_test/**              | Minimum SDK version compatibility tests           |
| **metrics/**                       | Size and performance metrics tooling              |
| **scripts/**                       | Build, release, and utility scripts               |
| **melos.yaml**                     | Melos monorepo configuration                      |

## Environment

Check if FVM is available via `which fvm` and prefer it over direct commands:

| Preferred Command | Fallback  |
| ----------------- | --------- |
| `fvm dart`        | `dart`    |
| `fvm flutter`     | `flutter` |

- **Dart-only**: No `flutter:` constraint in `environment:` section (e.g., `sentry`, `sentry_dio`)
- **Flutter**: Has `flutter:` constraint in `environment:` section (e.g., `sentry_flutter`, `sentry_sqflite`)

### Testing

Check the package's `pubspec.yaml` to determine if it's a Dart-only or Flutter package:

| Package Type     | Command                        |
| ---------------- | ------------------------------ |
| Dart packages    | `(fvm) dart test`              |
| Flutter packages | `(fvm) flutter test`           |
| Web tests        | `(fvm) flutter test -d chrome` |

Run tests from within the package directory (e.g., `packages/dart/` or `packages/flutter/`).

### Formatting & Analysis

| Task                     | Command                        |
| ------------------------ | ------------------------------ |
| Format code              | `(fvm) dart format <path>`     |
| Analyze Dart packages    | `(fvm) dart analyze <path>`    |
| Analyze Flutter packages | `(fvm) flutter analyze <path>` |

## Test Code Design

> **Note:** Existing tests may not follow these conventions. New and modified tests should adhere to these guidelines.

### Structure

**Rule:** Nested `group()` + `test()` names must read as a sentence when concatenated.

```
[Subject] [Context] [Variant] [Behavior]
  noun      prep       condition     verb
```

---

### Naming by Depth

| Level   | Use      | Style                  | Examples           |
| ------- | -------- | ---------------------- | ------------------ |
| Group 1 | Subject  | Noun                   | `Client`           |
| Group 2 | Context  | `when / in / during`   | `when connected`   |
| Group 3 | Variant  | `with / given / using` | `with valid input` |
| Test    | Behavior | Verb phrase            | `sends message`    |

---

### Depth Guidelines

- **Maximum depth: 3 groups.** If you need more nesting, consider refactoring the test or splitting into separate test files.
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

---

### Negative Tests

Use clear verb phrases that indicate the absence of behavior or expected failures:

| Pattern                  | Use Case                          | Example                     |
| ------------------------ | --------------------------------- | --------------------------- |
| `does not <verb>`        | Behavior is intentionally skipped | `does not send event`       |
| `throws <ExceptionType>` | Expected exception                | `throws ArgumentError`      |
| `returns null`           | Null result expected              | `returns null when missing` |
| `ignores <thing>`        | Input is deliberately ignored     | `ignores empty breadcrumbs` |

```dart
group('Client', () {
  group('when disabled', () {
    test('does not send events', () { });
    test('returns null for captureEvent', () { });
  });
});
```

---

### Example

```dart
group('Client', () {
  group('when connected', () {
    group('with valid token', () {
      test('sends message', () {});
    });
  });
});
```

→ "Client when connected with valid token sends message"

---

### One-Line Check

**If it doesn't read like a sentence, rename the groups.**

```
┌─────────────────────────────────────────────────────────────────────┐
│ group('<Subject>')                          // WHO - noun           │
│   group('<when/in/during Context>')         // WHEN/WHERE - prep    │
│     group('<with/given/for Variant>')       // WITH WHAT - condition│
│       test('<verb phrase>')                 // DOES WHAT - action   │
│                                                                     │
│ Result: Subject Context Variant verb-phrase                        │
│ Example: "Client when connected with valid token sends message"    │
└─────────────────────────────────────────────────────────────────────┘
```

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

### Fixture Pattern

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
- Initialize fixture in `setUp()` for each test group

### Test Options

Always use `defaultTestOptions()` from `test_utils.dart` to create options:

```dart
SentryOptions defaultTestOptions() {
  return SentryOptions(dsn: testDsn)..automatedTestMode = true;
}
```

### Test File Organization

When a test file grows large, consider splitting it into sub-files by context:

```
test/
├── hub_test.dart           # Main file, may contain simple tests
├── hub/
│   ├── hub_capturing_test.dart
│   ├── hub_scope_test.dart
│   └── hub_client_test.dart
```

- Prefer splitting when a single context (e.g., `Hub`) has many test groups
- Each sub-file should focus on one context or feature
- Keep the `Fixture` class in each sub-file or extract to a shared helper

## Dart Code Design

The repository follows roughly the conventions set by the [Effective Dart](https://dart.dev/effective-dart) guide.
