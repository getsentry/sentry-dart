import 'platform_checker.dart';

/// Reads environment variables from the system.
/// In an Flutter environment these can be set via
/// `flutter build --dart-define=VARIABLE_NAME=VARIABLE_VALUE`.
class EnvironmentVariables {
  static const _sentryEnvironment = 'SENTRY_ENVIRONMENT';
  static const _sentryDsn = 'SENTRY_DSN';
  static const _sentryRelease = 'SENTRY_RELEASE';
  static const _sentryDist = 'SENTRY_DSN';

  /// `SENTRY_ENVIRONMENT`
  /// See [SentryOptions.environment]
  String? get environment => const bool.hasEnvironment(_sentryEnvironment)
      ? const String.fromEnvironment(_sentryEnvironment)
      : null;

  /// `SENTRY_DSN`
  /// See [SentryOptions.dsn]
  String? get dsn => const bool.hasEnvironment(_sentryDsn)
      ? const String.fromEnvironment(_sentryDsn)
      : null;

  // `SENTRY_RELEASE`
  /// See [SentryOptions.release]
  String? get release => const bool.hasEnvironment(_sentryRelease)
      ? const String.fromEnvironment(_sentryRelease)
      : null;

  /// `SENTRY_DIST`
  /// See [SentryOptions.dist]
  String? get dist => const bool.hasEnvironment(_sentryDist)
      ? const String.fromEnvironment(_sentryDist)
      : null;

  /// Returns an environment based on the compilation mode of Dart or Flutter.
  /// This can be set as [SentryOptions.environment]
  String environmentForMode(PlatformChecker checker) {
    // We infer the enviroment based on the release/non-release and profile
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
