import '../platform_checker.dart';
import '_io_environment_variables.dart'
    if (dart.library.html) '_web_environment_variables.dart' as env;

/// Reads environment variables from the system.
/// In an Flutter environment these can be set via
/// `flutter build --dart-define=VARIABLE_NAME=VARIABLE_VALUE`.
abstract class EnvironmentVariables {
  factory EnvironmentVariables.instance() => env.envs;

  const EnvironmentVariables();

  /// `SENTRY_ENVIRONMENT`
  /// See [SentryOptions.environment]
  String? get environment;

  /// `SENTRY_DSN`
  /// See [SentryOptions.dsn]
  String? get dsn;

  /// `SENTRY_RELEASE`
  /// See [SentryOptions.release]
  String? get release;

  /// `SENTRY_DIST`
  /// See [SentryOptions.dist]
  String? get dist;

  /// Returns an environment based on the compilation mode of Dart or Flutter.
  /// This can be set as [SentryOptions.environment]
  String environmentForMode(PlatformChecker checker) {
    // We infer the environment based on the release/non-release and profile
    // constants.

    if (checker.isReleaseMode()) {
      return 'production';
    }
    if (checker.isProfileMode()) {
      return 'profile';
    }
    return 'debug';
  }
}
