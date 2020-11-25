import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';

import 'default_integrations.dart';
import 'file_system_transport.dart';
import 'version.dart';

mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    OptionsConfiguration optionsConfiguration,
    Function callback, {
    PackageLoader packageLoader = _loadPackageInfo,
    iOSPlatformChecker iOSPlatformChecker = _iOSPlatformChecker,
  }) async {
    await Sentry.init((options) async {
      await _initDefaultValues(
        options,
        callback,
        packageLoader,
        iOSPlatformChecker,
      );

      await optionsConfiguration(options);
    });
  }

  static Future<void> _initDefaultValues(
    SentryOptions options,
    Function callback,
    PackageLoader packageLoader,
    iOSPlatformChecker iOSPlatformChecker,
  ) async {
    // it is necessary to initialize Flutter method channels so that
    // our plugin can call into the native code.
    WidgetsFlutterBinding.ensureInitialized();

    options.debug = kDebugMode;

    // web still uses a http transport for Web which is set by default
    if (!kIsWeb) {
      options.transport = FileSystemTransport(_channel, options);
    }

    // if no environment is set, we set 'production' by default, but if we know it's
    // a non-release build, or the SENTRY_ENVIRONMENT is set, we read from it.
    if (const bool.hasEnvironment('SENTRY_ENVIRONMENT') || !kReleaseMode) {
      options.environment = const String.fromEnvironment('SENTRY_ENVIRONMENT',
          defaultValue: 'debug');
    }

    // if the SENTRY_DSN is set, we read from it.
    options.dsn = const bool.hasEnvironment('SENTRY_DSN')
        ? const String.fromEnvironment('SENTRY_DSN')
        : options.dsn;

    // TODO: load debug images when split symbols are enabled.

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    _addDefaultIntegrations(options, callback, iOSPlatformChecker);

    await _setReleaseAndDist(options, packageLoader);

    _setSdk(options);
  }

  static Future<void> _setReleaseAndDist(
    SentryOptions options,
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
    SentryOptions options,
    Function callback,
    iOSPlatformChecker isIOS,
  ) {
    // the ordering here matters, as we'd like to first start the native integration
    // that allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (!kIsWeb) {
      options.addIntegration(nativeSdkIntegration(options, _channel));
    }

    // will catch any errors that may occur in the Flutter framework itself.
    options.addIntegration(flutterErrorIntegration);

    // Throws when running on the browser
    if (!kIsWeb) {
      // catch any errors that may occur within the entry function, main()
      // in the ‘root zone’ where all Dart programs start
      options.addIntegration(isolateErrorIntegration);
    }

    // will enrich the events with the device context and native packages and integrations
    if (isIOS()) {
      options.addIntegration(loadContextsIntegration(options, _channel));
    }

    // finally the runZonedGuarded, catch any errors in Dart code running
    // ‘outside’ the Flutter framework
    options.addIntegration(runZonedGuardedIntegration(callback));
  }

  static void _setSdk(SentryOptions options) {
    // overwrite sdk info with current flutter sdk
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: List.from(options.sdk.integrations),
      packages: List.from(options.sdk.packages),
    );
    sdk.addPackage('pub:sentry_flutter', sdkVersion);
    options.sdk = sdk;
  }
}

typedef PackageLoader = Future<PackageInfo> Function();

typedef iOSPlatformChecker = bool Function();

/// Package info loader.
Future<PackageInfo> _loadPackageInfo() async {
  return await PackageInfo.fromPlatform();
}

/// verify if the platform is iOS
bool _iOSPlatformChecker() => Platform.isIOS;
