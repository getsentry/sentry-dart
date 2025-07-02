class SentryFeedbackOptions {
  // Form Configuration

  /// The title of the feedback form.
  var title = 'Report a Bug';

  /// Requires the name field on the feedback form to be filled in.
  var isNameRequired = false;

  /// Displays the name field on the feedback form. Ignored if `isNameRequired` is `true`.
  var showName = true;

  /// Requires the email field on the feedback form to be filled in.
  var isEmailRequired = false;

  /// Displays the email field on the feedback form. Ignored if `isEmailRequired` is `true`.
  var showEmail = true;

  /// Sets the `email` and `name` fields to the corresponding Sentry SDK user fields that were called with `SentrySDK.setUser`.
  var useSentryUser = true;

  /// Displays the Sentry logo inside the form
  var showBranding = true;

  /// Displays the capture screenshot button on the feedback form
  var showCaptureScreenshot = true;

  // Form Labels Configuration

  /// The title of the feedback form.
  String formTitle = 'Report a Bug';

  /// The label of the feedback description input field.
  String messageLabel = 'Description';

  /// The placeholder in the feedback description input field.
  String messagePlaceholder = 'What\'s the bug? What did you expect?';

  /// The text to attach to the title label for a required field.
  String isRequiredLabel = ' (Required)';

  /// The message displayed after a successful feedback submission.
  String successMessageText = 'Thank you for your report!';

  /// The label next to the name input field.
  String nameLabel = 'Name';

  /// The placeholder in the name input field.
  String namePlaceholder = 'Your Name';

  /// The label next to the email input field.
  String emailLabel = 'Email';

  /// The placeholder in the email input field.
  String emailPlaceholder = 'your.email@example.org';

  /// The label of the submit button.
  String submitButtonLabel = 'Send Bug Report';

  /// The label of the cancel button.
  String cancelButtonLabel = 'Cancel';

  /// The label of the validation error message.
  String validationErrorLabel = 'Can\'t be empty';

  /// The label of the capture screenshot button.
  String captureScreenshotButtonLabel = 'Capture a screenshot';

  /// The label of the remove screenshot button.
  String removeScreenshotButtonLabel = 'Remove screenshot';

  /// The label of the take screenshot button shown outside of the feedback widget.
  String takeScreenshotButtonLabel = 'Take Screenshot';
}
