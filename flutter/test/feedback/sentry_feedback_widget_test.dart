import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  group('$SentryFeedbackWidget show/hide ui elements', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('shows name field if showName is true', (tester) async {
      fixture.options.feedbackOptions.showName = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Name'), findsOne);
    });

    testWidgets('hides name field if showName is false', (tester) async {
      fixture.options.feedbackOptions.showName = false;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Name'), findsNothing);
    });

    testWidgets('shows email field if showEmail is true', (tester) async {
      fixture.options.feedbackOptions.showEmail = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Email'), findsOne);
    });

    testWidgets('hides email field if showEmail is false', (tester) async {
      fixture.options.feedbackOptions.showEmail = false;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Email'), findsNothing);
    });

    testWidgets('shows add screenshot button if showAddScreenshot is true',
        (tester) async {
      fixture.options.feedbackOptions.showAddScreenshot = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Add a screenshot'), findsOne);
    });

    testWidgets('hides add screenshot button if showAddScreenshot is false',
        (tester) async {
      fixture.options.feedbackOptions.showAddScreenshot = false;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Add a screenshot'), findsNothing);
    });

    testWidgets(
        'shows capture screenshot button if showCaptureScreenshot is true',
        (tester) async {
      fixture.options.feedbackOptions.showCaptureScreenshot = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Capture a screenshot'), findsOne);
    });

    testWidgets(
        'hides capture screenshot button if showCaptureScreenshot is false',
        (tester) async {
      fixture.options.feedbackOptions.showCaptureScreenshot = false;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.text('Capture a screenshot'), findsNothing);
    });

    testWidgets('shows sentry logo if showBranding is true', (tester) async {
      fixture.options.feedbackOptions.showBranding = true;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.byKey(const ValueKey('sentry_feedback_branding_logo')),
          findsOne);
    });

    testWidgets('hides sentry logo if showBranding is false', (tester) async {
      fixture.options.feedbackOptions.showBranding = false;
      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      expect(find.byKey(const ValueKey('sentry_feedback_branding_logo')),
          findsNothing);
    });
  });

  group('$SentryFeedbackWidget uses naming from options', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('when different naming is configured', (tester) async {
      fixture.options.feedbackOptions.isNameRequired = true;
      fixture.options.feedbackOptions.isEmailRequired = true;

      fixture.options.feedbackOptions.title = 'fixture-title';
      fixture.options.feedbackOptions.nameLabel = 'fixture-nameLabel';
      fixture.options.feedbackOptions.namePlaceholder =
          'fixture-namePlaceholder';
      fixture.options.feedbackOptions.emailLabel = 'fixture-emailLabel';
      fixture.options.feedbackOptions.emailPlaceholder =
          'fixture-emailPlaceholder';
      fixture.options.feedbackOptions.messageLabel = 'fixture-messageLabel';
      fixture.options.feedbackOptions.messagePlaceholder =
          'fixture-messagePlaceholder';
      fixture.options.feedbackOptions.submitButtonLabel =
          'fixture-submitButtonLabel';
      fixture.options.feedbackOptions.cancelButtonLabel =
          'fixture-cancelButtonLabel';
      fixture.options.feedbackOptions.isRequiredLabel =
          'fixture-isRequiredLabel';
      fixture.options.feedbackOptions.validationErrorLabel =
          'fixture-validationErrorLabel';

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
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
      expect(find.text('fixture-isRequiredLabel'), findsAny);

      await tester.tap(find.text('fixture-submitButtonLabel'));
      await tester.pumpAndSettle();

      expect(find.text('fixture-validationErrorLabel'), findsAny);
    });
  });

  group('$SentryFeedbackWidget submit', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('does add screenshot attachment to hint', (tester) async {
      // Source: https://evanhahn.com/worlds-smallest-png/
      final data = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x37,
        0x6E,
        0xF9,
        0x24,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x01,
        0x63,
        0x60,
        0x00,
        0x00,
        0x00,
        0x02,
        0x00,
        0x01,
        0x73,
        0x75,
        0x01,
        0x18,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82
      ];
      final screenshot = SentryAttachment.fromIntList(
        data,
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

  group('$SentryFeedbackWidget pending associatedEventId', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('sets pending accociatedEventId when taking screenshot',
        (tester) async {
      final associatedEventId =
          SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea');

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(
            hub: hub, associatedEventId: associatedEventId),
      );
      await tester.pumpAndSettle();

      final button = find
          .byKey(const ValueKey('sentry_feedback_capture_screenshot_button'));
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(SentryFeedbackWidget.pendingAccociatedEventId, associatedEventId);
    });

    testWidgets('clears pending accociatedEventId when submitting feedback',
        (tester) async {
      final associatedEventId =
          SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea');
      SentryFeedbackWidget.pendingAccociatedEventId = associatedEventId;

      when(fixture.hub.captureFeedback(
        any,
        hint: anyNamed('hint'),
        withScope: anyNamed('withScope'),
      )).thenAnswer((_) async => SentryId.empty());

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      await tester.enterText(
        find.byKey(ValueKey('sentry_feedback_message_textfield')),
        "fixture-message",
      );
      await tester.tap(find.text('Send Bug Report'));
      await tester.pumpAndSettle();

      expect(SentryFeedbackWidget.pendingAccociatedEventId, isNull);
    });

    testWidgets('clears pending accociatedEventId on cancel', (tester) async {
      final associatedEventId =
          SentryId.fromId('1988bb1b6f0d4c509e232f0cb9aaeaea');
      SentryFeedbackWidget.pendingAccociatedEventId = associatedEventId;

      await fixture.pumpFeedbackWidget(
        tester,
        (hub) => SentryFeedbackWidget(hub: hub),
      );

      await tester.enterText(
        find.byKey(ValueKey('sentry_feedback_message_textfield')),
        "fixture-message",
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(SentryFeedbackWidget.pendingAccociatedEventId, isNull);
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
