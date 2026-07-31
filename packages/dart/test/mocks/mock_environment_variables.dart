import 'package:sentry/src/environment/environment_variables.dart';

import 'no_such_method_provider.dart';

class MockEnvironmentVariables extends EnvironmentVariables
    with NoSuchMethodProvider {
  MockEnvironmentVariables({
    this._dist,
    this._dsn,
    this._environment,
    this._release,
  });

  final String? _dist;
  final String? _dsn;
  final String? _environment;
  final String? _release;

  @override
  String? get dist => _dist;

  @override
  String? get dsn => _dsn;

  @override
  String? get environment => _environment;

  @override
  String? get release => _release;
}
