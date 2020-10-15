/// Sentry response id

const _dashIndexed = [8, 13, 18, 23];

class SentryId {
  static final String emptyId =
      List.generate(36, (index) => _dashIndexed.contains(index) ? '-' : '0')
          .join();

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String id;

  const SentryId(this.id);

  factory SentryId.empty() => SentryId(emptyId);
}
