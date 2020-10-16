/// Sentry response id

class SentryId {
  static const String emptyId = '00000000-0000-0000-0000-000000000000';

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String id;

  const SentryId(this.id);

  factory SentryId.empty() => SentryId(emptyId);
}
