import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'sentry_flutter_options.dart';

import 'default_integrations.dart';
import 'file_system_transport.dart';
import 'version.dart';
// conditional import for the iOSPlatformChecker
// in browser, the iOSPlatformChecker will always return false
// the iOSPlatformChecker is used to run the loadContextsIntegration only on iOS.
// this injected PlatformChecker allows to test this behavior
import 'web_platform_checker.dart' if (dart.library.io) 'platform_checker.dart';

/// Configuration options callback
typedef FlutterOptionsConfiguration = FutureOr<void> Function(
    SentryFlutterOptions);

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    FlutterOptionsConfiguration optionsConfiguration, {
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
    final defaultIntegrations = _createDefaultIntegrations(
      isIOSChecker,
      isAndroidChecker,
      packageLoader,
    );

    if (appRunner != null) {
      final runBefore = () => WidgetsFlutterBinding.ensureInitialized();
      final runAfter = () => appRunner();
      final rzgi = RunZoneGuardedIntegration(runBefore, runAfter);
      flutterOptions.addIntegration(rzgi);

      for (final defaultIntegration in defaultIntegrations) {
        flutterOptions.addIntegration(defaultIntegration);
      }
    } else {
      WidgetsFlutterBinding.ensureInitialized();
      for (final defaultIntegration in defaultIntegrations) {
        flutterOptions.addIntegration(defaultIntegration);
      }
    }

    await _initDefaultValues(flutterOptions);

    await Sentry.init(
      (options) async {
        await optionsConfiguration(options);
      },
      appRunner: null, // Handled by RunZoneGuardedIntegration
      options: flutterOptions,
    );
  }

  static Future<void> _initDefaultValues(
    SentryFlutterOptions options,
  ) async {
    options.debug = kDebugMode;

    // web still uses a http transport for Web which is set by default
    if (!kIsWeb) {
      options.transport = FileSystemTransport(_channel, options);
    }

    _setSdk(options);
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static List<Integration> _createDefaultIntegrations(
    iOSPlatformChecker isIOS,
    AndroidPlatformChecker isAndroid,
    PackageLoader packageLoader,
  ) {
    final integrations = <Integration>[];

    // will catch any errors that may occur in the Flutter framework itself.
    integrations.add(FlutterErrorIntegration());

    // This tracks Flutter application events, such as lifecycle events.
    integrations.add(WidgetsBindingIntegration());

    // the ordering here matters, as we'd like to first start the native integration
    // that allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (!kIsWeb) {
      integrations.add(NativeSdkIntegration(_channel));
    }

    // will enrich the events with the device context and native packages and integrations
    if (isIOS()) {
      integrations.add(LoadContextsIntegration(_channel));
    }

    if (isAndroid()) {
      integrations.add(LoadAndroidImageListIntegration(_channel));
    }

    // this is an Integration because we want to execute after all the
    // error handlers are in place, calling a Channel might result
    // in errors.
    integrations.add(LoadReleaseIntegration(packageLoader));

    return integrations;
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

/// an iOS PlatformChecker wrapper to make it testable
typedef iOSPlatformChecker = bool Function();

/// an Android PlatformChecker wrapper to make it testable
typedef AndroidPlatformChecker = bool Function();

/// Package info loader.
Future<PackageInfo> _loadPackageInfo() async {
  return await PackageInfo.fromPlatform();
}
