import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Hexadecimal string representing a uuid4 value
@immutable
class SentryId {
  static final SentryId _emptyId =
      SentryId.fromId('00000000-0000-0000-0000-000000000000');

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String _id;

  static final Uuid _uuidGenerator = Uuid();

  SentryId._internal({String id}) : _id = id ?? _uuidGenerator.v4();

  /// Generates a new SentryId
  factory SentryId.newId() => SentryId._internal();

  /// Generates a SentryId with the given UUID
  factory SentryId.fromId(String id) => SentryId._internal(id: id);

  /// SentryId with an empty UUID
  factory SentryId.empty() => _emptyId;

  @override
  String toString() => _id.replaceAll('-', '');
}
