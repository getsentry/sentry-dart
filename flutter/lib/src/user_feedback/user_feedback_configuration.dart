// coverage:ignore-file
// Data class without logic

class UserFeedbackConfiguration {
  const UserFeedbackConfiguration({
    this.title = "It looks like we're having issues.",
    this.subtitle =
        "Our team has been notified. If you'd like to help, tell us what happened below.",
    this.labelName = 'Name',
    this.labelEmail = 'Email',
    this.labelComments = 'What happened?',
    this.labelClose = 'Close',
    this.labelSubmit = 'Submit',
    this.labelFieldMustNotBeEmpty = 'This field must not be empty.',
    this.labelFieldMustBeAValidEmail = 'This field must contain a valid email.',
    this.showPoweredBy = true,
  });

  /// "It looks like we're having issues."
  final String title;

  /// "Our team has been notified."
  final String subtitle;

  /// "Name"
  final String labelName;

  /// "Email"
  final String labelEmail;

  /// "What happened?"
  final String labelComments;

  /// "Close"
  final String labelClose;

  /// "Submit"
  final String labelSubmit;

  /// Whether the Sentry logo should be shown.
  final bool showPoweredBy;

  /// "This field must not be empty."
  final String labelFieldMustNotBeEmpty;

  /// "This field must contain a valid email."
  final String labelFieldMustBeAValidEmail;
}
