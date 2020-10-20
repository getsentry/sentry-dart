/// Sentry response id

class SentryId {
  static const String _emptyId = '00000000-0000-0000-0000-000000000000';

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String _id;

  // TODO: should we generate the new UUID here with an empty ctor?

  const SentryId(this._id);

  factory SentryId.empty() => SentryId(_emptyId);

  @override
  String toString() => _id.replaceAll('-', '');
}
