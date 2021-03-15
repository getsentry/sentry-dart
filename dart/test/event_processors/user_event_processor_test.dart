import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processors/user_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('UserEventProcessor', () {
    test('sendDefaultPii is disabled', () async {
      var options = SentryOptions(dsn: fakeDsn);
      options.sendDefaultPii = false;

      var event = await userEventProcessor(options, fakeEvent);

      expect(event, fakeEvent);
    });

    test('sendDefaultPii is enabled and event has no user', () async {
      var options = SentryOptions(dsn: fakeDsn);
      options.sendDefaultPii = true;
      var fakeEvent = SentryEvent();

      var processedEvent = await userEventProcessor(options, fakeEvent);

      expect(processedEvent, isNotNull);
      expect(processedEvent?.user, isNotNull);
      expect(processedEvent?.user?.ipAddress, '{{auto}}');
    });

    test('sendDefaultPii is enabled and event has a user with IP address',
        () async {
      var options = SentryOptions(dsn: fakeDsn);
      options.sendDefaultPii = true;

      var processedEvent = await userEventProcessor(options, fakeEvent);

      expect(processedEvent, isNotNull);
      expect(processedEvent?.user, isNotNull);
      // fakeEvent has a user which is not null
      expect(processedEvent?.user?.ipAddress, fakeEvent.user!.ipAddress);
      expect(processedEvent?.user?.id, fakeEvent.user!.id);
      expect(processedEvent?.user?.email, fakeEvent.user!.email);
    });

    test('sendDefaultPii is enabled and event has a user without IP address',
        () async {
      var options = SentryOptions(dsn: fakeDsn);
      options.sendDefaultPii = true;
      final event = fakeEvent.copyWith(user: fakeUser);

      var processedEvent = await userEventProcessor(options, event);

      expect(processedEvent, isNotNull);
      expect(processedEvent?.user, isNotNull);
      expect(processedEvent?.user?.ipAddress, '{{auto}}');
      expect(processedEvent?.user?.id, fakeUser.id);
      expect(processedEvent?.user?.email, fakeUser.email);
    });
  });
}
