# Sentry Development Guide for AI Agents

## Overview

Sentry is a developer-first error tracking and performance monitoring platform.
This repository contains the Sentry Dart/Flutter SDK and integrations with third party libraries.

## Project Structure

- `packages/` - SDK packages (Melos monorepo)
- `packages/dart/` - Core Sentry Dart SDK
- `packages/flutter/` - Sentry Flutter SDK (includes native integrations)
- `packages/dio/` - Dio HTTP client integration
- `packages/drift/` - Drift database integration
- `packages/file/` - File I/O integration
- `packages/hive/` - Hive database integration
- `packages/isar/` - Isar database integration
- `packages/sqflite/` - SQLite integration
- `packages/logging/` - Dart logging package integration
- `packages/supabase/` - Supabase integration
- `packages/firebase_remote_config/` - Firebase Remote Config integration
- `packages/link/` - Deep linking integration
- `docs/` - Documentation and release checklists
- `e2e_test/` - End-to-end test suite
- `min_version_test/` - Minimum SDK version compatibility tests
- `metrics/` - Size and performance metrics tooling
- `scripts/` - Build, release, and utility scripts
- `melos.yaml` - Melos monorepo configuration

## Environment

- Flutter Version: `3.24.0`
- Dart Version: `3.5.0`

Check if FVM is available via `which fvm` and prefer it over direct commands:

- `fvm dart` - preferred command, fallback to `dart`
- `fvm flutter` - preferred command, fallback to `flutter`

Package type detection:

- **Dart-only** - no `flutter:` constraint in `environment:` section (e.g., `sentry`, `sentry_dio`)
- **Flutter** - has `flutter:` constraint in `environment:` section (e.g., `sentry_flutter`, `sentry_sqflite`)

### Testing

Check the package's `pubspec.yaml` to determine if it's a Dart-only or Flutter package:

- Dart packages - run `(fvm) dart test`
- Flutter packages - run `(fvm) flutter test`
- Web tests - run `(fvm) flutter test -d chrome`

Run tests from within the package directory (e.g., `packages/dart/` or `packages/flutter/`).

### Formatting & Analysis

- Format code - run `(fvm) dart format <path>`
- Analyze Dart packages - run `(fvm) dart analyze <path>`
- Analyze Flutter packages - run `(fvm) flutter analyze <path>`

## Test Code Design

> **Note:** Existing tests may not follow these conventions. New and modified tests should adhere to these guidelines.

### Structure

**Rule:** Nested `group()` + `test()` names must read as a sentence when concatenated.

Pattern: `[Subject] [Context] [Variant] [Behavior]`

- Subject = noun (e.g., `Client`)
- Context = preposition phrase (e.g., `when connected`)
- Variant = condition (e.g., `with valid input`)
- Behavior = verb phrase (e.g., `sends message`)

---

### Naming by Depth

- Group 1 (Subject) - use Noun style - example: `Client`
- Group 2 (Context) - use `when / in / during` style - example: `when connected`
- Group 3 (Variant) - use `with / given / using` style - example: `with valid input`
- Test (Behavior) - use Verb phrase style - example: `sends message`

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

> **Note:** Existing code may not follow these conventions. New and modified tests should adhere to these guidelines.

Prefer modern Dart language features supported by the Dart version specified above when they improve clarity, reduce boilerplate, and do not compromise readability. Examples include:

- **Sealed Classes** - Exhaustive pattern matching with restricted hierarchies
- **Extension Types** - Zero-cost wrappers around existing types
- **Records** - Lightweight multi-value returns: `(String, int)` or `({String name, int age})`
- **Pattern Matching** - Destructuring in `switch`, `if-case`, variable declarations
- **Switch Expressions** - Expression-based switches returning values
- **Class Modifiers** - `final`, `base`, `interface`, `mixin` class modifiers
- **Enhanced Enums** - Enums with fields, constructors, and methods
- **If-Case Expressions** - Pattern matching in if statements
- **Null-Aware Elements** - `?maybeNull` in collection literals

Apply these guidelines when writing or reviewing code:

### Identifiers

- [DO name types using `UpperCamelCase`.](https://dart.dev/effective-dart/style#do-name-types-using-uppercamelcase)
- [DO name extensions using `UpperCamelCase`.](https://dart.dev/effective-dart/style#do-name-extensions-using-uppercamelcase)
- [DO name packages, directories, and source files using `lowercase_with_underscores`.](https://dart.dev/effective-dart/style#do-name-packages-and-file-system-entities-using-lowercase-with-underscores)
- [DO name import prefixes using `lowercase_with_underscores`.](https://dart.dev/effective-dart/style#do-name-import-prefixes-using-lowercase_with_underscores)
- [DO name other identifiers using `lowerCamelCase`.](https://dart.dev/effective-dart/style#do-name-other-identifiers-using-lowercamelcase)
- [PREFER using `lowerCamelCase` for constant names.](https://dart.dev/effective-dart/style#prefer-using-lowercamelcase-for-constant-names)
- [DO capitalize acronyms and abbreviations longer than two letters like words.](https://dart.dev/effective-dart/style#do-capitalize-acronyms-and-abbreviations-longer-than-two-letters-like-words)
- [PREFER using wildcards for unused callback parameters.](https://dart.dev/effective-dart/style#prefer-using-wildcards-for-unused-callback-parameters)
- [DON'T use a leading underscore for identifiers that aren't private.](https://dart.dev/effective-dart/style#dont-use-a-leading-underscore-for-identifiers-that-arent-private)
- [DON'T use prefix letters.](https://dart.dev/effective-dart/style#dont-use-prefix-letters)
- [DON'T explicitly name libraries.](https://dart.dev/effective-dart/style#dont-explicitly-name-libraries)

### Ordering

- [DO place `dart:` imports before other imports.](https://dart.dev/effective-dart/style#do-place-dart-imports-before-other-imports)
- [DO place `package:` imports before relative imports.](https://dart.dev/effective-dart/style#do-place-package-imports-before-relative-imports)
- [DO specify exports in a separate section after all imports.](https://dart.dev/effective-dart/style#do-specify-exports-in-a-separate-section-after-all-imports)
- [DO sort sections alphabetically.](https://dart.dev/effective-dart/style#do-sort-sections-alphabetically)

### Formatting

- [DO format your code using `dart format`.](https://dart.dev/effective-dart/style#do-format-your-code-using-dart-format)
- [CONSIDER changing your code to make it more formatter-friendly.](https://dart.dev/effective-dart/style#consider-changing-your-code-to-make-it-more-formatter-friendly)
- [PREFER lines 80 characters or fewer.](https://dart.dev/effective-dart/style#prefer-lines-80-characters-or-fewer)
- [DO use curly braces for all flow control statements.](https://dart.dev/effective-dart/style#do-use-curly-braces-for-all-flow-control-statements)

### Comments

- [DO format comments like sentences.](https://dart.dev/effective-dart/documentation#do-format-comments-like-sentences)
- [DON'T use block comments for documentation.](https://dart.dev/effective-dart/documentation#dont-use-block-comments-for-documentation)

### Doc Comments

- [DO use `///` doc comments to document members and types.](https://dart.dev/effective-dart/documentation#do-use-doc-comments-to-document-members-and-types)
- [PREFER writing doc comments for public APIs.](https://dart.dev/effective-dart/documentation#prefer-writing-doc-comments-for-public-apis)
- [CONSIDER writing a library-level doc comment.](https://dart.dev/effective-dart/documentation#consider-writing-a-library-level-doc-comment)
- [CONSIDER writing doc comments for private APIs.](https://dart.dev/effective-dart/documentation#consider-writing-doc-comments-for-private-apis)
- [DO start doc comments with a single-sentence summary.](https://dart.dev/effective-dart/documentation#do-start-doc-comments-with-a-single-sentence-summary)
- [DO separate the first sentence of a doc comment into its own paragraph.](https://dart.dev/effective-dart/documentation#do-separate-the-first-sentence-of-a-doc-comment-into-its-own-paragraph)
- [AVOID redundancy with the surrounding context.](https://dart.dev/effective-dart/documentation#avoid-redundancy-with-the-surrounding-context)
- [PREFER starting comments of a function or method with third-person verbs if its main purpose is a side effect.](https://dart.dev/effective-dart/documentation#prefer-starting-comments-of-a-function-or-method-with-third-person-verbs-if-its-main-purpose-is-a-side-effect)
- [PREFER starting a non-boolean variable or property comment with a noun phrase.](https://dart.dev/effective-dart/documentation#prefer-starting-a-non-boolean-variable-or-property-comment-with-a-noun-phrase)
- [PREFER starting a boolean variable or property comment with "Whether" followed by a noun or gerund phrase.](https://dart.dev/effective-dart/documentation#prefer-starting-a-boolean-variable-or-property-comment-with-whether-followed-by-a-noun-or-gerund-phrase)
- [PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose.](https://dart.dev/effective-dart/documentation#prefer-a-noun-phrase-or-non-imperative-verb-phrase-for-a-function-or-method-if-returning-a-value-is-its-primary-purpose)
- [DON'T write documentation for both the getter and setter of a property.](https://dart.dev/effective-dart/documentation#dont-write-documentation-for-both-the-getter-and-setter-of-a-property)
- [PREFER starting library or type comments with noun phrases.](https://dart.dev/effective-dart/documentation#prefer-starting-library-or-type-comments-with-noun-phrases)
- [CONSIDER including code samples in doc comments.](https://dart.dev/effective-dart/documentation#consider-including-code-samples-in-doc-comments)
- [DO use square brackets in doc comments to refer to in-scope identifiers.](https://dart.dev/effective-dart/documentation#do-use-square-brackets-in-doc-comments-to-refer-to-in-scope-identifiers)
- [DO use prose to explain parameters, return values, and exceptions.](https://dart.dev/effective-dart/documentation#do-use-prose-to-explain-parameters-return-values-and-exceptions)
- [DO put doc comments before metadata annotations.](https://dart.dev/effective-dart/documentation#do-put-doc-comments-before-metadata-annotations)

### Markdown

- [AVOID using markdown excessively.](https://dart.dev/effective-dart/documentation#avoid-using-markdown-excessively)
- [AVOID using HTML for formatting.](https://dart.dev/effective-dart/documentation#avoid-using-html-for-formatting)
- [PREFER backtick fences for code blocks.](https://dart.dev/effective-dart/documentation#prefer-backtick-fences-for-code-blocks)

### Writing

- [PREFER brevity.](https://dart.dev/effective-dart/documentation#prefer-brevity)
- [AVOID abbreviations and acronyms unless they are obvious.](https://dart.dev/effective-dart/documentation#avoid-abbreviations-and-acronyms-unless-they-are-obvious)
- [PREFER using "this" instead of "the" to refer to a member's instance.](https://dart.dev/effective-dart/documentation#prefer-using-this-instead-of-the-to-refer-to-a-members-instance)

### Libraries

- [DO use strings in `part of` directives.](https://dart.dev/effective-dart/usage#do-use-strings-in-part-of-directives)
- [DON'T import libraries that are inside the `src` directory of another package.](https://dart.dev/effective-dart/usage#dont-import-libraries-that-are-inside-the-src-directory-of-another-package)
- [DON'T allow an import path to reach into or out of `lib`.](https://dart.dev/effective-dart/usage#dont-allow-an-import-path-to-reach-into-or-out-of-lib)
- [PREFER relative import paths.](https://dart.dev/effective-dart/usage#prefer-relative-import-paths)

### Null

- [DON'T explicitly initialize variables to `null`.](https://dart.dev/effective-dart/usage#dont-explicitly-initialize-variables-to-null)
- [DON'T use an explicit default value of `null`.](https://dart.dev/effective-dart/usage#dont-use-an-explicit-default-value-of-null)
- [DON'T use `true` or `false` in equality operations.](https://dart.dev/effective-dart/usage#dont-use-true-or-false-in-equality-operations)
- [AVOID `late` variables if you need to check whether they are initialized.](https://dart.dev/effective-dart/usage#avoid-late-variables-if-you-need-to-check-whether-they-are-initialized)
- [CONSIDER type promotion or null-check patterns for using nullable types.](https://dart.dev/effective-dart/usage#consider-type-promotion-or-null-check-patterns-for-using-nullable-types)

### Strings

- [DO use adjacent strings to concatenate string literals.](https://dart.dev/effective-dart/usage#do-use-adjacent-strings-to-concatenate-string-literals)
- [PREFER using interpolation to compose strings and values.](https://dart.dev/effective-dart/usage#prefer-using-interpolation-to-compose-strings-and-values)
- [AVOID using curly braces in interpolation when not needed.](https://dart.dev/effective-dart/usage#avoid-using-curly-braces-in-interpolation-when-not-needed)

### Collections

- [DO use collection literals when possible.](https://dart.dev/effective-dart/usage#do-use-collection-literals-when-possible)
- [DON'T use `.length` to see if a collection is empty.](https://dart.dev/effective-dart/usage#dont-use-length-to-see-if-a-collection-is-empty)
- [AVOID using `Iterable.forEach()` with a function literal.](https://dart.dev/effective-dart/usage#avoid-using-iterable-foreach-with-a-function-literal)
- [DON'T use `List.from()` unless you intend to change the type of the result.](https://dart.dev/effective-dart/usage#dont-use-list-from-unless-you-intend-to-change-the-type-of-the-result)
- [DO use `whereType()` to filter a collection by type.](https://dart.dev/effective-dart/usage#do-use-wheretype-to-filter-a-collection-by-type)
- [DON'T use `cast()` when a nearby operation will do.](https://dart.dev/effective-dart/usage#dont-use-cast-when-a-nearby-operation-will-do)
- [AVOID using `cast()`.](https://dart.dev/effective-dart/usage#avoid-using-cast)

### Functions

- [DO use a function declaration to bind a function to a name.](https://dart.dev/effective-dart/usage#do-use-a-function-declaration-to-bind-a-function-to-a-name)
- [DON'T create a lambda when a tear-off will do.](https://dart.dev/effective-dart/usage#dont-create-a-lambda-when-a-tear-off-will-do)

### Variables

- [DO follow a consistent rule for `var` and `final` on local variables.](https://dart.dev/effective-dart/usage#do-follow-a-consistent-rule-for-var-and-final-on-local-variables)
- [AVOID storing what you can calculate.](https://dart.dev/effective-dart/usage#avoid-storing-what-you-can-calculate)

### Members

- [DON'T wrap a field in a getter and setter unnecessarily.](https://dart.dev/effective-dart/usage#dont-wrap-a-field-in-a-getter-and-setter-unnecessarily)
- [PREFER using a `final` field to make a read-only property.](https://dart.dev/effective-dart/usage#prefer-using-a-final-field-to-make-a-read-only-property)
- [CONSIDER using `=>` for simple members.](https://dart.dev/effective-dart/usage#consider-using-for-simple-members)
- [DON'T use `this.` except to redirect to a named constructor or to avoid shadowing.](https://dart.dev/effective-dart/usage#dont-use-this-when-not-needed-to-avoid-shadowing)
- [DO initialize fields at their declaration when possible.](https://dart.dev/effective-dart/usage#do-initialize-fields-at-their-declaration-when-possible)

### Constructors

- [DO use initializing formals when possible.](https://dart.dev/effective-dart/usage#do-use-initializing-formals-when-possible)
- [DON'T use `late` when a constructor initializer list will do.](https://dart.dev/effective-dart/usage#dont-use-late-when-a-constructor-initializer-list-will-do)
- [DO use `;` instead of `{}` for empty constructor bodies.](https://dart.dev/effective-dart/usage#do-use-instead-of-for-empty-constructor-bodies)
- [DON'T use `new`.](https://dart.dev/effective-dart/usage#dont-use-new)
- [DON'T use `const` redundantly.](https://dart.dev/effective-dart/usage#dont-use-const-redundantly)
- [CONSIDER making your constructor `const` if the class supports it.](https://dart.dev/effective-dart/design#consider-making-your-constructor-const-if-the-class-supports-it)

### Error Handling

- [AVOID catches without `on` clauses.](https://dart.dev/effective-dart/usage#avoid-catches-without-on-clauses)
- [DON'T discard errors from catches without `on` clauses.](https://dart.dev/effective-dart/usage#dont-discard-errors-from-catches-without-on-clauses)
- [DO throw objects that implement `Error` only for programmatic errors.](https://dart.dev/effective-dart/usage#do-throw-objects-that-implement-error-only-for-programmatic-errors)
- [DON'T explicitly catch `Error` or types that implement it.](https://dart.dev/effective-dart/usage#dont-explicitly-catch-error-or-types-that-implement-it)
- [DO use `rethrow` to rethrow a caught exception.](https://dart.dev/effective-dart/usage#do-use-rethrow-to-rethrow-a-caught-exception)

### Asynchrony

- [PREFER async/await over using raw futures.](https://dart.dev/effective-dart/usage#prefer-asyncawait-over-using-raw-futures)
- [DON'T use `async` when it has no useful effect.](https://dart.dev/effective-dart/usage#dont-use-async-when-it-has-no-useful-effect)
- [CONSIDER using higher-order methods to transform a stream.](https://dart.dev/effective-dart/usage#consider-using-higher-order-methods-to-transform-a-stream)
- [AVOID using Completer directly.](https://dart.dev/effective-dart/usage#avoid-using-completer-directly)
- [DO test for `Future<T>` when disambiguating a `FutureOr<T>` whose type argument could be `Object`.](https://dart.dev/effective-dart/usage#do-test-for-futuret-when-disambiguating-a-futureort-whose-type-argument-could-be-object)

### Names

- [DO use terms consistently.](https://dart.dev/effective-dart/design#do-use-terms-consistently)
- [AVOID abbreviations.](https://dart.dev/effective-dart/design#avoid-abbreviations)
- [PREFER putting the most descriptive noun last.](https://dart.dev/effective-dart/design#prefer-putting-the-most-descriptive-noun-last)
- [CONSIDER making the code read like a sentence.](https://dart.dev/effective-dart/design#consider-making-the-code-read-like-a-sentence)
- [PREFER a noun phrase for a non-boolean property or variable.](https://dart.dev/effective-dart/design#prefer-a-noun-phrase-for-a-non-boolean-property-or-variable)
- [PREFER a non-imperative verb phrase for a boolean property or variable.](https://dart.dev/effective-dart/design#prefer-a-non-imperative-verb-phrase-for-a-boolean-property-or-variable)
- [CONSIDER omitting the verb for a named boolean _parameter_.](https://dart.dev/effective-dart/design#consider-omitting-the-verb-for-a-named-boolean-parameter)
- [PREFER the "positive" name for a boolean property or variable.](https://dart.dev/effective-dart/design#prefer-the-positive-name-for-a-boolean-property-or-variable)
- [PREFER an imperative verb phrase for a function or method whose main purpose is a side effect.](https://dart.dev/effective-dart/design#prefer-an-imperative-verb-phrase-for-a-function-or-method-whose-main-purpose-is-a-side-effect)
- [PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose.](https://dart.dev/effective-dart/design#prefer-a-noun-phrase-or-non-imperative-verb-phrase-for-a-function-or-method-if-returning-a-value-is-its-primary-purpose)
- [CONSIDER an imperative verb phrase for a function or method if you want to draw attention to the work it performs.](https://dart.dev/effective-dart/design#consider-an-imperative-verb-phrase-for-a-function-or-method-if-you-want-to-draw-attention-to-the-work-it-performs)
- [AVOID starting a method name with `get`.](https://dart.dev/effective-dart/design#avoid-starting-a-method-name-with-get)
- [PREFER naming a method `to___()` if it copies the object's state to a new object.](https://dart.dev/effective-dart/design#prefer-naming-a-method-to___-if-it-copies-the-objects-state-to-a-new-object)
- [PREFER naming a method `as___()` if it returns a different representation backed by the original object.](https://dart.dev/effective-dart/design#prefer-naming-a-method-as___-if-it-returns-a-different-representation-backed-by-the-original-object)
- [AVOID describing the parameters in the function's or method's name.](https://dart.dev/effective-dart/design#avoid-describing-the-parameters-in-the-functions-or-methods-name)
- [DO follow existing mnemonic conventions when naming type parameters.](https://dart.dev/effective-dart/design#do-follow-existing-mnemonic-conventions-when-naming-type-parameters)

### Classes and Mixins

- [AVOID defining a one-member abstract class when a simple function will do.](https://dart.dev/effective-dart/design#avoid-defining-a-one-member-abstract-class-when-a-simple-function-will-do)
- [AVOID defining a class that contains only static members.](https://dart.dev/effective-dart/design#avoid-defining-a-class-that-contains-only-static-members)
- [AVOID extending a class that isn't intended to be subclassed.](https://dart.dev/effective-dart/design#avoid-extending-a-class-that-isnt-intended-to-be-subclassed)
- [DO use class modifiers to control if your class can be extended.](https://dart.dev/effective-dart/design#do-use-class-modifiers-to-control-if-your-class-can-be-extended)
- [AVOID implementing a class that isn't intended to be an interface.](https://dart.dev/effective-dart/design#avoid-implementing-a-class-that-isnt-intended-to-be-an-interface)
- [DO use class modifiers to control if your class can be an interface.](https://dart.dev/effective-dart/design#do-use-class-modifiers-to-control-if-your-class-can-be-an-interface)
- [PREFER defining a pure `mixin` or pure `class` to a `mixin class`.](https://dart.dev/effective-dart/design#prefer-defining-a-pure-mixin-or-pure-class-to-a-mixin-class)
- [PREFER making declarations private.](https://dart.dev/effective-dart/design#prefer-making-declarations-private)
- [CONSIDER declaring multiple classes in the same library.](https://dart.dev/effective-dart/design#consider-declaring-multiple-classes-in-the-same-library)

### Types

- [DO type annotate variables without initializers.](https://dart.dev/effective-dart/design#do-type-annotate-variables-without-initializers)
- [DO type annotate fields and top-level variables if the type isn't obvious.](https://dart.dev/effective-dart/design#do-type-annotate-fields-and-top-level-variables-if-the-type-isnt-obvious)
- [DON'T redundantly type annotate initialized local variables.](https://dart.dev/effective-dart/design#dont-redundantly-type-annotate-initialized-local-variables)
- [DO annotate return types on function declarations.](https://dart.dev/effective-dart/design#do-annotate-return-types-on-function-declarations)
- [DO annotate parameter types on function declarations.](https://dart.dev/effective-dart/design#do-annotate-parameter-types-on-function-declarations)
- [DON'T annotate inferred parameter types on function expressions.](https://dart.dev/effective-dart/design#dont-annotate-inferred-parameter-types-on-function-expressions)
- [DON'T type annotate initializing formals.](https://dart.dev/effective-dart/design#dont-type-annotate-initializing-formals)
- [DO write type arguments on generic invocations that aren't inferred.](https://dart.dev/effective-dart/design#do-write-type-arguments-on-generic-invocations-that-arent-inferred)
- [DON'T write type arguments on generic invocations that are inferred.](https://dart.dev/effective-dart/design#dont-write-type-arguments-on-generic-invocations-that-are-inferred)
- [AVOID writing incomplete generic types.](https://dart.dev/effective-dart/design#avoid-writing-incomplete-generic-types)
- [DO annotate with `dynamic` instead of letting inference fail.](https://dart.dev/effective-dart/design#do-annotate-with-dynamic-instead-of-letting-inference-fail)
- [PREFER signatures in function type annotations.](https://dart.dev/effective-dart/design#prefer-signatures-in-function-type-annotations)
- [DON'T specify a return type for a setter.](https://dart.dev/effective-dart/design#dont-specify-a-return-type-for-a-setter)
- [DON'T use the legacy typedef syntax.](https://dart.dev/effective-dart/design#dont-use-the-legacy-typedef-syntax)
- [PREFER inline function types over typedefs.](https://dart.dev/effective-dart/design#prefer-inline-function-types-over-typedefs)
- [PREFER using function type syntax for parameters.](https://dart.dev/effective-dart/design#prefer-using-function-type-syntax-for-parameters)
- [AVOID using `dynamic` unless you want to disable static checking.](https://dart.dev/effective-dart/design#avoid-using-dynamic-unless-you-want-to-disable-static-checking)
- [DO use `Future<void>` as the return type of asynchronous members that do not produce values.](https://dart.dev/effective-dart/design#do-use-futurevoid-as-the-return-type-of-asynchronous-members-that-do-not-produce-values)
- [AVOID using `FutureOr<T>` as a return type.](https://dart.dev/effective-dart/design#avoid-using-futureort-as-a-return-type)
- [PREFER making fields and top-level variables `final`.](https://dart.dev/effective-dart/design#prefer-making-fields-and-top-level-variables-final)
- [DO use getters for operations that conceptually access properties.](https://dart.dev/effective-dart/design#do-use-getters-for-operations-that-conceptually-access-properties)
- [DO use setters for operations that conceptually change properties.](https://dart.dev/effective-dart/design#do-use-setters-for-operations-that-conceptually-change-properties)
- [DON'T define a setter without a corresponding getter.](https://dart.dev/effective-dart/design#dont-define-a-setter-without-a-corresponding-getter)
- [AVOID using runtime type tests to fake overloading.](https://dart.dev/effective-dart/design#avoid-using-runtime-type-tests-to-fake-overloading)
- [AVOID public `late final` fields without initializers.](https://dart.dev/effective-dart/design#avoid-public-late-final-fields-without-initializers)
- [AVOID returning nullable `Future`, `Stream`, and collection types.](https://dart.dev/effective-dart/design#avoid-returning-nullable-future-stream-and-collection-types)
- [AVOID returning `this` from methods just to enable a fluent interface.](https://dart.dev/effective-dart/design#avoid-returning-this-from-methods-just-to-enable-a-fluent-interface)

### Parameters

- [AVOID positional boolean parameters.](https://dart.dev/effective-dart/design#avoid-positional-boolean-parameters)
- [AVOID optional positional parameters if the user may want to omit earlier parameters.](https://dart.dev/effective-dart/design#avoid-optional-positional-parameters-if-the-user-may-want-to-omit-earlier-parameters)
- [AVOID mandatory parameters that accept a special "no argument" value.](https://dart.dev/effective-dart/design#avoid-mandatory-parameters-that-accept-a-special-no-argument-value)
- [DO use inclusive start and exclusive end parameters to accept a range.](https://dart.dev/effective-dart/design#do-use-inclusive-start-and-exclusive-end-parameters-to-accept-a-range)

### Equality

- [DO override `hashCode` if you override `==`.](https://dart.dev/effective-dart/design#do-override-hashcode-if-you-override)
- [DO make your `==` operator obey the mathematical rules of equality.](https://dart.dev/effective-dart/design#do-make-your-operator-obey-the-mathematical-rules-of-equality)
- [AVOID defining custom equality for mutable classes.](https://dart.dev/effective-dart/design#avoid-defining-custom-equality-for-mutable-classes)
- [DON'T make the parameter to `==` nullable.](https://dart.dev/effective-dart/design#dont-make-the-parameter-to-nullable)

## Development

### When Stuck

- Ask a clarifying question or propose a short plan
- Do not push large speculative changes without confirmation

### Test First Mode

- When adding new features: write or update unit tests first, then code to green
- For regressions: add a failing test that reproduces the bug, then fix to green
