# Dart/Flutter Code Guidelines

> **Note:** Existing code may not follow these conventions. New and modified code should adhere to these guidelines.

Use only language features available in the Dart/Flutter versions specified in `AGENTS.md`.

## SDK Development Rules

### Integrations

Encapsulate SDK features as `Integration` classes that implement `call()` and `close()`:

- Check feature flags and prerequisites early, log and return if disabled
- Register the integration via `options.sdk.addIntegration(name)`
- Clean up resources in `close()` if needed
- See `packages/flutter/lib/src/integrations/` for examples
- Integrations should be order-independent; if yours requires running before/after another, reconsider the design

### Privacy

- Never collect Personally Identifiable Information (PII) without checking `options.sendDefaultPii`
- Flag any changes that could leak PII for review

### Breaking Changes

- Signal breaking changes clearly (API removals, behavior changes, renamed options)
- Prefer deprecation with migration path over immediate removal

### Native Code (JNI/FFI)

- Release all native memory (JNI local refs, malloc allocations)
- Handle native exceptions gracefully—don't crash the host app

### File Organization

- Prefer grouping related files by feature in sub-directories (e.g., `metrics/`)
- Avoid flat structures with many unrelated files in one directory

## Modern Dart Features

Prefer modern Dart language features (Dart 3.5+) when they improve clarity and reduce boilerplate:

- **Sealed Classes** - Exhaustive pattern matching with restricted hierarchies
- **Extension Types** - Zero-cost wrappers around existing types
- **Records** - Lightweight multi-value returns: `(String, int)` or `({String name, int age})`
- **Pattern Matching** - Destructuring in `switch`, `if-case`, variable declarations
- **Switch Expressions** - Expression-based switches returning values
- **Class Modifiers** - `final`, `base`, `interface`, `mixin` class modifiers
- **Enhanced Enums** - Enums with fields, constructors, and methods
- **If-Case Expressions** - Pattern matching in if statements
- **Null-Aware Elements** - `?maybeNull` in collection literals

## Semantic Naming Guidelines

### General Naming

- [DO use terms consistently.](https://dart.dev/effective-dart/design#do-use-terms-consistently)
- [AVOID abbreviations.](https://dart.dev/effective-dart/design#avoid-abbreviations)
- [PREFER putting the most descriptive noun last.](https://dart.dev/effective-dart/design#prefer-putting-the-most-descriptive-noun-last)
- [CONSIDER making the code read like a sentence.](https://dart.dev/effective-dart/design#consider-making-the-code-read-like-a-sentence)

### Properties and Variables

- [PREFER a noun phrase for a non-boolean property or variable.](https://dart.dev/effective-dart/design#prefer-a-noun-phrase-for-a-non-boolean-property-or-variable)
- [PREFER a non-imperative verb phrase for a boolean property or variable.](https://dart.dev/effective-dart/design#prefer-a-non-imperative-verb-phrase-for-a-boolean-property-or-variable)
- [CONSIDER omitting the verb for a named boolean _parameter_.](https://dart.dev/effective-dart/design#consider-omitting-the-verb-for-a-named-boolean-parameter)
- [PREFER the "positive" name for a boolean property or variable.](https://dart.dev/effective-dart/design#prefer-the-positive-name-for-a-boolean-property-or-variable)

### Methods and Functions

- [PREFER an imperative verb phrase for a function or method whose main purpose is a side effect.](https://dart.dev/effective-dart/design#prefer-an-imperative-verb-phrase-for-a-function-or-method-whose-main-purpose-is-a-side-effect)
- [PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose.](https://dart.dev/effective-dart/design#prefer-a-noun-phrase-or-non-imperative-verb-phrase-for-a-function-or-method-if-returning-a-value-is-its-primary-purpose)
- [CONSIDER an imperative verb phrase for a function or method if you want to draw attention to the work it performs.](https://dart.dev/effective-dart/design#consider-an-imperative-verb-phrase-for-a-function-or-method-if-you-want-to-draw-attention-to-the-work-it-performs)
- [AVOID starting a method name with `get`.](https://dart.dev/effective-dart/design#avoid-starting-a-method-name-with-get)
- [PREFER naming a method `to___()` if it copies the object's state to a new object.](https://dart.dev/effective-dart/design#prefer-naming-a-method-to___-if-it-copies-the-objects-state-to-a-new-object)
- [PREFER naming a method `as___()` if it returns a different representation backed by the original object.](https://dart.dev/effective-dart/design#prefer-naming-a-method-as___-if-it-returns-a-different-representation-backed-by-the-original-object)
- [AVOID describing the parameters in the function's or method's name.](https://dart.dev/effective-dart/design#avoid-describing-the-parameters-in-the-functions-or-methods-name)

### Type Parameters

- [DO follow existing mnemonic conventions when naming type parameters.](https://dart.dev/effective-dart/design#do-follow-existing-mnemonic-conventions-when-naming-type-parameters)

## Dart Code Design

### Classes and Abstractions

- [AVOID defining a one-member abstract class when a simple function will do.](https://dart.dev/effective-dart/design#avoid-defining-a-one-member-abstract-class-when-a-simple-function-will-do)
- [AVOID defining a class that contains only static members.](https://dart.dev/effective-dart/design#avoid-defining-a-class-that-contains-only-static-members)
- [DO use class modifiers to control if your class can be extended.](https://dart.dev/effective-dart/design#do-use-class-modifiers-to-control-if-your-class-can-be-extended)
- [DO use class modifiers to control if your class can be an interface.](https://dart.dev/effective-dart/design#do-use-class-modifiers-to-control-if-your-class-can-be-an-interface)
- [PREFER defining a pure `mixin` or pure `class` to a `mixin class`.](https://dart.dev/effective-dart/design#prefer-defining-a-pure-mixin-or-pure-class-to-a-mixin-class)
- [PREFER making declarations private.](https://dart.dev/effective-dart/design#prefer-making-declarations-private)

### Asynchrony

- [PREFER async/await over using raw futures.](https://dart.dev/effective-dart/usage#prefer-asyncawait-over-using-raw-futures)
- [CONSIDER using higher-order methods to transform a stream.](https://dart.dev/effective-dart/usage#consider-using-higher-order-methods-to-transform-a-stream)
- [AVOID using Completer directly.](https://dart.dev/effective-dart/usage#avoid-using-completer-directly)

### Types and Nullability

- [AVOID `late` variables if you need to check whether they are initialized.](https://dart.dev/effective-dart/usage#avoid-late-variables-if-you-need-to-check-whether-they-are-initialized)
- [CONSIDER type promotion or null-check patterns for using nullable types.](https://dart.dev/effective-dart/usage#consider-type-promotion-or-null-check-patterns-for-using-nullable-types)
- [DO use `Future<void>` as the return type of asynchronous members that do not produce values.](https://dart.dev/effective-dart/design#do-use-futurevoid-as-the-return-type-of-asynchronous-members-that-do-not-produce-values)
- [AVOID returning nullable `Future`, `Stream`, and collection types.](https://dart.dev/effective-dart/design#avoid-returning-nullable-future-stream-and-collection-types)

### Parameters

- [AVOID positional boolean parameters.](https://dart.dev/effective-dart/design#avoid-positional-boolean-parameters)
- [AVOID optional positional parameters if the user may want to omit earlier parameters.](https://dart.dev/effective-dart/design#avoid-optional-positional-parameters-if-the-user-may-want-to-omit-earlier-parameters)
- [AVOID mandatory parameters that accept a special "no argument" value.](https://dart.dev/effective-dart/design#avoid-mandatory-parameters-that-accept-a-special-no-argument-value)
- [DO use inclusive start and exclusive end parameters to accept a range.](https://dart.dev/effective-dart/design#do-use-inclusive-start-and-exclusive-end-parameters-to-accept-a-range)

### Equality

- [DO override `hashCode` if you override `==`.](https://dart.dev/effective-dart/design#do-override-hashcode-if-you-override)
- [DO make your `==` operator obey the mathematical rules of equality.](https://dart.dev/effective-dart/design#do-make-your-operator-obey-the-mathematical-rules-of-equality)
- [AVOID defining custom equality for mutable classes.](https://dart.dev/effective-dart/design#avoid-defining-custom-equality-for-mutable-classes)

### Doc Comments

- [AVOID redundancy with the surrounding context.](https://dart.dev/effective-dart/documentation#avoid-redundancy-with-the-surrounding-context)
- [DO use `///` doc comments to document members and types.](https://dart.dev/effective-dart/documentation#do-use-doc-comments-to-document-members-and-types)
- [PREFER writing doc comments for public APIs.](https://dart.dev/effective-dart/documentation#prefer-writing-doc-comments-for-public-apis)
- [CONSIDER writing a library-level doc comment.](https://dart.dev/effective-dart/documentation#consider-writing-a-library-level-doc-comment)
- [CONSIDER writing doc comments for private APIs.](https://dart.dev/effective-dart/documentation#consider-writing-doc-comments-for-private-apis)
- [DO start doc comments with a single-sentence summary.](https://dart.dev/effective-dart/documentation#do-start-doc-comments-with-a-single-sentence-summary)
- [DO separate the first sentence of a doc comment into its own paragraph.](https://dart.dev/effective-dart/documentation#do-separate-the-first-sentence-of-a-doc-comment-into-its-own-paragraph)
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
