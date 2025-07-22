// This tests that the base functionality of the hooks function correctly.

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('SdkLifecycleRegistry', () {
    test('registers callback for given event type', () {
      final registry = fixture.getSut();
      final cb = (OnBeforeSendEvent _) {};

      registry.registerCallback<OnBeforeSendEvent>(cb);

      expect(registry.lifecycleCallbacks[OnBeforeSendEvent], contains(cb));
    });

    test('removes previously registered callback', () {
      final registry = fixture.getSut();
      final cb = (OnBeforeSendEvent _) {};

      registry.registerCallback<OnBeforeSendEvent>(cb);
      registry.removeCallback<OnBeforeSendEvent>(cb);

      final callbacks = registry.lifecycleCallbacks[OnBeforeSendEvent];
      expect(callbacks, isNotNull);
      expect(callbacks, isEmpty);
    });

    test('dispatch executes registered synchronous callback', () async {
      final registry = fixture.getSut();
      var executed = false;
      final cb = (OnBeforeSendEvent _) {
        executed = true;
      };

      registry.registerCallback<OnBeforeSendEvent>(cb);

      await registry.dispatchCallback<OnBeforeSendEvent>(
        OnBeforeSendEvent(SentryEvent(), Hint()),
      );

      expect(executed, isTrue);
    });

    test('dispatch executes registered asynchronous callback', () async {
      final registry = fixture.getSut();
      var executed = false;
      final cb = (OnBeforeSendEvent _) async {
        await Future<void>.delayed(Duration.zero);
        executed = true;
      };

      registry.registerCallback<OnBeforeSendEvent>(cb);

      await registry.dispatchCallback<OnBeforeSendEvent>(
        OnBeforeSendEvent(SentryEvent(), Hint()),
      );

      expect(executed, isTrue);
    });

    test('dispatch does not execute callback after removal', () async {
      final registry = fixture.getSut();
      var executed = false;
      final cb = (OnBeforeSendEvent _) {
        executed = true;
      };

      registry.registerCallback<OnBeforeSendEvent>(cb);
      registry.removeCallback<OnBeforeSendEvent>(cb);

      await registry.dispatchCallback<OnBeforeSendEvent>(
        OnBeforeSendEvent(SentryEvent(), Hint()),
      );

      expect(executed, isFalse);
    });

    test('dispatch rethrows exception when automatedTestMode is enabled',
        () async {
      final registry = fixture.getSut();
      final cb = (OnBeforeSendEvent _) {
        throw StateError('failure in callback');
      };

      registry.registerCallback<OnBeforeSendEvent>(cb);

      expect(
        () async => registry.dispatchCallback<OnBeforeSendEvent>(
          OnBeforeSendEvent(SentryEvent(), Hint()),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class Fixture {
  final SentryOptions options = defaultTestOptions();

  SdkLifecycleRegistry getSut() {
    return SdkLifecycleRegistry(options);
  }
}
