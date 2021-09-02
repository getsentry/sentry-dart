import 'environment_variables.dart';
import 'keys.dart';

final EnvironmentVariables envs = WebEnvironmentVariables();

class WebEnvironmentVariables extends EnvironmentVariables {
  @override
  String? get environment => const bool.hasEnvironment(sentryEnvironment)
      ? const String.fromEnvironment(sentryEnvironment)
      : null;

  @override
  String? get dsn => const bool.hasEnvironment(sentryDsn)
      ? const String.fromEnvironment(sentryDsn)
      : null;

  @override
  String? get release => const bool.hasEnvironment(sentryRelease)
      ? const String.fromEnvironment(sentryRelease)
      : null;

  @override
  String? get dist => const bool.hasEnvironment(sentryDist)
      ? const String.fromEnvironment(sentryDist)
      : null;
}
