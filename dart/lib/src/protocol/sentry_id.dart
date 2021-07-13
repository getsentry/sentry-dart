import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Hexadecimal string representing a uuid4 value.
/// The length is exactly 32
/// characters. Dashes are not allowed. Has to be lowercase.
@immutable
class SentryId {
  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String _id;

  static final Uuid _uuidGenerator = Uuid();

  SentryId._internal({String? id})
      : _id =
            id?.replaceAll('-', '') ?? _uuidGenerator.v4().replaceAll('-', '');

  /// Generates a new SentryId
  SentryId.newId() : this._internal();

  /// Generates a SentryId with the given UUID
  SentryId.fromId(String id) : this._internal(id: id);

  /// SentryId with an empty UUID
  const SentryId.empty() : _id = '00000000000000000000000000000000';

  @override
  String toString() => _id;

  @override
  int get hashCode => _id.hashCode;

  @override
  bool operator ==(o) {
    if (o is SentryId) {
      return o._id == _id;
    }
    return false;
  }
}
