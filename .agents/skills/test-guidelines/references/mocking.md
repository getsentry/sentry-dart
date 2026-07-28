# Mocking and Designing for Mockability

The full guidance behind the one-line summary in [SKILL.md](../SKILL.md).

## Prefer fakes over mocks

- **Prefer fakes over mocks.** Fakes are hand-written implementations that capture state, making tests resilient to refactoring and readable as documentation. Use them as the default for test doubles.
- Only reach for mocks when faking is impractical, e.g. a large third-party interface where writing a full fake isn't worth the effort.
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

## Designing for mockability

A test double can only be substituted at a seam the code actually exposes. If a test is hard to fake, the code under test is usually the problem — fix the design, not the test. (This is the testability side of **design-first**; shape the code there, verify it here.)

- **The code must accept its dependencies for a fake to substitute.** This is the testability trio that **design-first** owns (accept deps, return results, small surface) — here it's just the test-side consequence: a class that receives its transport/client/clock can be faked in `Fixture.getSut()`; one that constructs them internally cannot.

  ```dart
  // GOOD: dependency injected → fake it in getSut()
  SentryClient(this._options); // _options.transport is set by the test

  // HARD TO TEST: dependency constructed internally
  SentryClient() : _transport = HttpTransport(); // test can't replace it
  ```

- **Prefer SDK-style interfaces over one generic call.** A double for `getUser()` / `sendEnvelope()` returns one known shape; a double for a single generic `request(endpoint, options)` needs conditional logic inside the fake to decide what to return. Specific per-operation methods keep fakes trivial and make it obvious which operations a test exercises.

- **Mock only at real boundaries** — transport, native interop, the clock, randomness, the filesystem. Don't fake your own in-process collaborators; test through them.
