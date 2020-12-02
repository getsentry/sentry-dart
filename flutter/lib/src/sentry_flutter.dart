import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';

import 'default_integrations.dart';
import 'file_system_transport.dart';
import 'sentry_flutter_options.dart';
import 'version.dart';
// conditional import for the iOSPlatformChecker
// in browser, the iOSPlatformChecker will always return false
// the iOSPlatformChecker is used to run the loadContextsIntegration only on iOS.
// this injected PlatformChecker allows to test this behavior
import 'web_platform_checker.dart' if (dart.library.io) 'platform_checker.dart';

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    OptionsConfiguration optionsConfiguration, {
    AppRunner appRunner,
    PackageLoader packageLoader = _loadPackageInfo,
    iOSPlatformChecker isIOSChecker = isIOS,
    AndroidPlatformChecker isAndroidChecker = isAndroid,
  }) async {
    if (optionsConfiguration == null) {
      throw ArgumentError('OptionsConfiguration is required.');
    }
    final flutterOptions = SentryFlutterOptions();
    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    _addDefaultIntegrations(flutterOptions, isIOS, isAndroidChecker);

    await Sentry.init(
      (options) async {
        await _initDefaultValues(
          options,
          packageLoader,
          isIOSChecker,
          isAndroidChecker,
        );

        await optionsConfiguration(options);
      },
      appRunner: appRunner,
      options: flutterOptions,
    );
  }

  static Future<void> _initDefaultValues(
    SentryFlutterOptions options,
    PackageLoader packageLoader,
    iOSPlatformChecker isIOSChecker,
    AndroidPlatformChecker isAndroidChecker,
  ) async {
    // it is necessary to initialize Flutter method channels so that
    // our plugin can call into the native code.
    WidgetsFlutterBinding.ensureInitialized();

    options.debug = kDebugMode;

    // web still uses a http transport for Web which is set by default
    if (!kIsWeb) {
      options.transport = FileSystemTransport(_channel, options);
    }

    await _setReleaseAndDist(options, packageLoader);

    _setSdk(options);
  }

  static Future<void> _setReleaseAndDist(
    SentryFlutterOptions options,
    PackageLoader packageLoader,
  ) async {
    try {
      if (!kIsWeb) {
        if (packageLoader == null) {
          options.logger(SentryLevel.debug, 'Package loader is null.');
          return;
        }
        final packageInfo = await packageLoader();
        final release =
            '${packageInfo.packageName}@${packageInfo.version}+${packageInfo.buildNumber}';
        options.logger(SentryLevel.debug, 'release: $release');

        options.release = release;
        options.dist = packageInfo.buildNumber;
      } else {
        // for non-mobile builds, we read the release and dist from the
        // system variables (SENTRY_RELEASE and SENTRY_DIST).
        options.release = const bool.hasEnvironment('SENTRY_RELEASE')
            ? const String.fromEnvironment('SENTRY_RELEASE')
            : options.release;
        options.dist = const bool.hasEnvironment('SENTRY_DIST')
            ? const String.fromEnvironment('SENTRY_DIST')
            : options.dist;
      }
    } catch (error) {
      options.logger(
          SentryLevel.error, 'Failed to load release and dist: $error');
    }
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static void _addDefaultIntegrations(
    SentryFlutterOptions options,
    iOSPlatformChecker isIOS,
    AndroidPlatformChecker isAndroidChecker,
  ) {
    // will catch any errors that may occur in the Flutter framework itself.
    options.addIntegration(FlutterErrorIntegration());

    // the ordering here matters, as we'd like to first start the native integration
    // that allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (!kIsWeb) {
      options.addIntegration(NativeSdkIntegration(_channel));
    }

    // will enrich the events with the device context and native packages and integrations
    if (isIOS()) {
      options.addIntegration(LoadContextsIntegration(_channel));
    }

    if (isAndroidChecker()) {
      options.addIntegration(LoadAndroidImageListIntegration(_channel));
    }
  }

  static void _setSdk(SentryFlutterOptions options) {
    // overwrite sdk info with current flutter sdk
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: options.sdk.integrations,
      packages: options.sdk.packages,
    );
    sdk.addPackage('pub:sentry_flutter', sdkVersion);
    options.sdk = sdk;
  }
}

/// a PackageInfo wrapper to make it testable
typedef PackageLoader = Future<PackageInfo> Function();

/// an iOS PlatformChecker wrapper to make it testable
typedef iOSPlatformChecker = bool Function();

/// an Android PlatformChecker wrapper to make it testable
typedef AndroidPlatformChecker = bool Function();

/// Package info loader.
Future<PackageInfo> _loadPackageInfo() async {
  return await PackageInfo.fromPlatform();
}
