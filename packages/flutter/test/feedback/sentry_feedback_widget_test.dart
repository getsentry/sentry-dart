import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('SentryFeedbackWidget', () {
    tearDown(() {
      SentryFeedbackForm.pendingAssociatedEventId = null;
      SentryFeedbackForm.clearPreservedData();
    });

    test('is a deprecated alias for SentryFeedbackForm', () {
      expect(SentryFeedbackWidget, SentryFeedbackForm);
    });

    test('shares static form state with SentryFeedbackForm', () {
      final associatedEventId = SentryId.fromId(
        '1988bb1b6f0d4c509e232f0cb9aaeaea',
      );

      SentryFeedbackWidget.pendingAssociatedEventId = associatedEventId;
      SentryFeedbackWidget.preservedName = 'fixture-name';
      SentryFeedbackWidget.preservedEmail = 'fixture@example.com';
      SentryFeedbackWidget.preservedMessage = 'fixture-message';

      expect(SentryFeedbackForm.pendingAssociatedEventId, associatedEventId);
      expect(SentryFeedbackForm.preservedName, 'fixture-name');
      expect(SentryFeedbackForm.preservedEmail, 'fixture@example.com');
      expect(SentryFeedbackForm.preservedMessage, 'fixture-message');
    });
  });
}
