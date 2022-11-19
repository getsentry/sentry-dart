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
}
