import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryFeedbackWidget validation', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('does not call hub on submit if not valid', (tester) async {
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      verifyNever(
        fixture.hub.captureFeedback(
          captureAny,
          hint: anyNamed('hint'),
          withScope: anyNamed('withScope'),
        ),
      );
    });

    testWidgets('shows error on submit if message not valid', (tester) async {
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t be empty'), findsOne);
      expect(find.text(' (Required)'), findsOne);
    });

    testWidgets('shows error on submit if name not valid', (tester) async {
      fixture.options.feedbackOptions.isNameRequired = true;

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
        ),
      );

      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t be empty'), findsExactly(2));
      expect(find.text(' (Required)'), findsExactly(2));
    });

    testWidgets('shows error on submit if email not valid', (tester) async {
      fixture.options.feedbackOptions.isEmailRequired = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
        ),
      );

      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t be empty'), findsExactly(2));
      expect(find.text(' (Required)'), findsExactly(2));
    });

    testWidgets('shows error on submit if name and email not valid',
        (tester) async {
      fixture.options.feedbackOptions.isNameRequired = true;
      fixture.options.feedbackOptions.isEmailRequired = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
        ),
      );

      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      expect(find.text('Can\'t be empty'), findsExactly(3));
      expect(find.text(' (Required)'), findsExactly(3));
    });
  });

  group('$SentryFeedbackWidget submit', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('does add screenshot attachment to hint', (tester) async {
      final ByteData pngData =
          await rootBundle.load('assets/screenshotIcon.png');
      final screenshot = SentryAttachment.fromByteData(
        pngData,
        'test.png',
        contentType: 'image/png',
      );

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
          screenshot: screenshot,
        ),
      );

      when(fixture.hub.captureFeedback(
        any,
        hint: anyNamed('hint'),
        withScope: anyNamed('withScope'),
      )).thenAnswer(
          (_) async => SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea'));

      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_name_textfield')),
          "fixture-name");
      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_email_textfield')),
          "fixture-email");
      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_message_textfield')),
          "fixture-message");
      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      verify(fixture.hub.captureFeedback(
        any,
        hint: argThat(predicate<Hint>((hint) => hint.screenshot == screenshot),
            named: 'hint'),
        withScope: anyNamed('withScope'),
      )).called(1);
    });

    testWidgets('does call hub captureFeedback on submit', (tester) async {
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
          associatedEventId:
              SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea'),
        ),
      );

      when(fixture.hub.captureFeedback(
        any,
        hint: anyNamed('hint'),
        withScope: anyNamed('withScope'),
      )).thenAnswer(
          (_) async => SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea'));

      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_name_textfield')),
          "fixture-name");
      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_email_textfield')),
          "fixture-email");
      await tester.enterText(
          find.byKey(ValueKey('sentry_feedback_message_textfield')),
          "fixture-message");
      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      verify(fixture.hub.captureFeedback(
        argThat(predicate<SentryFeedback>((feedback) =>
            feedback.name == 'fixture-name' &&
            feedback.contactEmail == 'fixture-email' &&
            feedback.message == 'fixture-message' &&
            feedback.associatedEventId ==
                SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea'))),
        hint: anyNamed('hint'),
        withScope: anyNamed('withScope'),
      )).called(1);
    });
  });

  group('$SentryFeedbackWidget localization', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('sets labels and hints from feedbackoptions', (tester) async {
      final options = fixture.options;
      options.feedbackOptions.title = 'fixture-title';
      options.feedbackOptions.nameLabel = 'fixture-nameLabel';
      options.feedbackOptions.namePlaceholder = 'fixture-namePlaceholder';
      options.feedbackOptions.emailLabel = 'fixture-emailLabel';
      options.feedbackOptions.emailPlaceholder = 'fixture-emailPlaceholder';
      options.feedbackOptions.messageLabel = 'fixture-messageLabel';
      options.feedbackOptions.messagePlaceholder = 'fixture-messagePlaceholder';
      options.feedbackOptions.submitButtonLabel = 'fixture-submitButtonLabel';
      options.feedbackOptions.cancelButtonLabel = 'fixture-cancelButtonLabel';
      options.feedbackOptions.isRequiredLabel = 'fixture-isRequiredLabel';
      options.feedbackOptions.validationErrorLabel =
          'fixture-validationErrorLabel';

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
          hub: hub,
        ),
      );

      expect(find.text('fixture-title'), findsOne);
      expect(find.text('fixture-nameLabel'), findsOne);
      expect(find.text('fixture-namePlaceholder'), findsOne);
      expect(find.text('fixture-emailLabel'), findsOne);
      expect(find.text('fixture-emailPlaceholder'), findsOne);
      expect(find.text('fixture-messageLabel'), findsOne);
      expect(find.text('fixture-messagePlaceholder'), findsOne);
      expect(find.text('fixture-submitButtonLabel'), findsOne);
      expect(find.text('fixture-cancelButtonLabel'), findsOne);
      expect(find.text('fixture-isRequiredLabel'), findsOne);

      await tester.tap(find.text('fixture-submitButtonLabel'));
      await tester.pumpAndSettle();

      expect(find.text('fixture-validationErrorLabel'), findsOne);
    });
  });
}

class Fixture {
  var options = SentryFlutterOptions();
  var hub = MockHub();

  Fixture() {
    when(hub.options).thenReturn(options);
  }

  Future<void> pumpFeedbackWidget(
      WidgetTester tester, Widget Function(Hub) builder) async {
    await tester.pumpWidget(
      MaterialApp(
        home: builder(hub),
      ),
    );
  }
}
