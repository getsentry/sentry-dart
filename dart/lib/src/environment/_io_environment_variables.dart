import 'dart:io';

import '_web_environment_variables.dart';
import 'environment_variables.dart';
import 'keys.dart';

final EnvironmentVariables envs = IoEnvironmentVariables();

/// In addition to dart defines this io implementation can read from the
/// environment variables.
class IoEnvironmentVariables extends WebEnvironmentVariables {
  @override
  String? get environment =>
      super.environment ?? Platform.environment[sentryEnvironment];

  @override
  String? get dsn => super.dsn ?? Platform.environment[sentryDsn];

  @override
  String? get release => super.release ?? Platform.environment[sentryRelease];

  @override
  String? get dist => super.dist ?? Platform.environment[sentryDist];
}
