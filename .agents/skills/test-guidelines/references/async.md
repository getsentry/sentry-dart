# Async Tests

The full guidance behind the one-line summary in [SKILL.md](../SKILL.md).

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
