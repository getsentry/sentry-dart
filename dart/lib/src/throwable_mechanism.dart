import 'protocol/mechanism.dart';

/// An Error decorator that holds a Mechanism related to the decorated Error
class ThrowableMechanism extends Error {
  final Mechanism _mechanism;
  final dynamic _throwable;

  ThrowableMechanism(this._mechanism, this._throwable);

  Mechanism get mechanism => _mechanism;

  dynamic get throwable => _throwable;
}
