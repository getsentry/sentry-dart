import 'dart:io';

import 'environment_variables.dart';
import 'keys.dart';

final EnvironmentVariables envs = IoEnvironmentVariables();

/// In addition to dart defines this io implementation can read from the
/// environment variables.
class IoEnvironmentVariables extends EnvironmentVariables {
  @override
  String? get environment {
    if (const bool.hasEnvironment(sentryEnvironment)) {
      return const String.fromEnvironment(sentryEnvironment);
    }
    return Platform.environment[sentryEnvironment];
  }

  @override
  String? get dsn {
    if (const bool.hasEnvironment(sentryDsn)) {
      return const String.fromEnvironment(sentryDsn);
    }
    return Platform.environment[sentryDsn];
  }

  @override
  String? get release {
    if (const bool.hasEnvironment(sentryRelease)) {
      return const String.fromEnvironment(sentryRelease);
    }
    return Platform.environment[sentryRelease];
  }

  @override
  String? get dist {
    if (const bool.hasEnvironment(sentryDist)) {
      return const String.fromEnvironment(sentryDist);
    }
    return Platform.environment[sentryDist];
  }
}
