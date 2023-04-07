import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// An [Integration] that loads the release version from native apps
class LoadReleaseIntegration extends Integration<SentryFlutterOptions> {
  LoadReleaseIntegration();

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      if (options.release == null || options.dist == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        var name = _cleanString(packageInfo.packageName);
        if (name.isEmpty) {
          // Not all platforms have a packageName.
          // If no packageName is available, use the appName instead.
          name = _cleanString(packageInfo.appName);
        }

        final version = _cleanString(packageInfo.version);
        final buildNumber = _cleanString(packageInfo.buildNumber);

        var release = name;
        if (version.isNotEmpty) {
          release = '$release@$version';
        }
        // At least windows sometimes does not have a buildNumber
        if (buildNumber.isNotEmpty) {
          release = '$release+$buildNumber';
        }

        options.logger(SentryLevel.debug, 'release: $release');

        options.release = options.release ?? release;
        if (buildNumber.isNotEmpty) {
          options.dist = options.dist ?? buildNumber;
        }
      }
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.error,
        'Failed to load release and dist',
        exception: exception,
        stackTrace: stackTrace,
      );
    }

    options.sdk.addIntegration('loadReleaseIntegration');
  }

  /// This method cleans the given string from characters which should not be
  /// used.
  /// For example https://docs.sentry.io/platforms/flutter/configuration/releases/#bind-the-version
  /// imposes some requirements. Also Windows uses some characters which
  /// should not be used.
  String _cleanString(String appName) {
    // Replace disallowed chars with an underscore '_'
    return appName
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('\t', '_')
        .replaceAll('\r\n', '_')
        .replaceAll('\r', '_')
        .replaceAll('\n', '_')
        // replace Unicode NULL character with an empty string
        .replaceAll('\u{0000}', '');
  }
}
