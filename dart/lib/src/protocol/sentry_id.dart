import 'package:uuid/uuid.dart';

class SentryId {
  static const String _emptyId = '00000000-0000-0000-0000-000000000000';

  /// SentryId with an empty UUID
  static final SentryId emptyId = SentryId.fromId(_emptyId);

  /// The ID Sentry.io assigned to the submitted event for future reference.
  String _id;

  final Uuid _uuidGenerator = Uuid();

  SentryId._internal({String id}) {
    _id = id ?? _uuidGenerator.v4();
  }

  /// Generates a new SentryId
  factory SentryId.newId() => SentryId._internal();

  /// Generates a SentryId with the given UUID
  factory SentryId.fromId(String id) => SentryId._internal(id: id);

  @override
  String toString() => _id.replaceAll('-', '');
}
