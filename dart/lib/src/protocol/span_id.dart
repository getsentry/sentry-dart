import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// The length is exactly 16 characters.
/// Dashes are not allowed. Has to be lowercase.
@immutable
class SpanId {
  final String _id;

  static final Uuid _uuidGenerator = Uuid();

  SpanId._internal({String? id})
      : _id = id?.replaceAll('-', '') ??
            _uuidGenerator.v4().replaceAll('-', '').substring(0, 16);

  /// Generates a new SpanId
  SpanId.newId() : this._internal();

  /// Generates a SpanId with the given UUID
  SpanId.fromId(String id) : this._internal(id: id);

  /// SpanId with an empty UUID
  const SpanId.empty() : _id = '0000000000000000';

  @override
  String toString() => _id;

  @override
  int get hashCode => _id.hashCode;

  @override
  bool operator ==(o) {
    if (o is SpanId) {
      return o._id == _id;
    }
    return false;
  }
}
