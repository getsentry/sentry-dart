import 'package:sentry/src/environment/environment_variables.dart';

import 'no_such_method_provider.dart';

class MockEnvironmentVariables extends EnvironmentVariables
    with NoSuchMethodProvider {
  MockEnvironmentVariables({
    String? dist,
    String? dsn,
    String? environment,
    String? release,
  })  : _dist = dist,
        _dsn = dsn,
        _environment = environment,
        _release = release;

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
