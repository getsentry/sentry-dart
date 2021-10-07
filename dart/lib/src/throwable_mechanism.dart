import 'protocol/mechanism.dart';

/// A decorator that holds a Mechanism related to the decorated Exception
class ThrowableMechanism implements Exception {
  final Mechanism _mechanism;
  final dynamic _throwable;

  ThrowableMechanism(this._mechanism, this._throwable);

  Mechanism get mechanism => _mechanism;

  dynamic get throwable => _throwable;
}
