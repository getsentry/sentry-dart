import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'sentry_flutter_options.dart';

import 'default_integrations.dart';
import 'file_system_transport.dart';
import 'version.dart';

/// Configuration options callback
typedef FlutterOptionsConfiguration = FutureOr<void> Function(
    SentryFlutterOptions);

/// Sentry Flutter SDK main entry point
mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<void> init(
    FlutterOptionsConfiguration optionsConfiguration, {
    AppRunner? appRunner,
    PackageLoader packageLoader = _loadPackageInfo,
    MethodChannel channel = _channel,
    SentryFlutterOptions? options,
  }) async {
    final flutterOptions = options ?? SentryFlutterOptions();

    // first step is to install the native integration and set default values,
    // so we are able to capture future errors.
    final defaultIntegrations = _createDefaultIntegrations(
      packageLoader,
      channel,
      flutterOptions,
    );
    for (final defaultIntegration in defaultIntegrations) {
      flutterOptions.addIntegration(defaultIntegration);
    }

    await _initDefaultValues(flutterOptions, channel);

    await Sentry.init(
      (options) async {
        await optionsConfiguration(options as SentryFlutterOptions);
      },
      appRunner: appRunner,
      options: flutterOptions,
    );
  }

  static Future<void> _initDefaultValues(
    SentryFlutterOptions options,
    MethodChannel channel,
  ) async {
    // Not all platforms have a native integration.
    if (options.platformChecker.hasNativeIntegration) {
      options.transport = FileSystemTransport(channel, options);
    }

    _setSdk(options);
  }

  /// Install default integrations
  /// https://medium.com/flutter-community/error-handling-in-flutter-98fce88a34f0
  static List<Integration> _createDefaultIntegrations(
    PackageLoader packageLoader,
    MethodChannel channel,
    SentryFlutterOptions options,
  ) {
    final integrations = <Integration>[];

    // Will call WidgetsFlutterBinding.ensureInitialized() before all other integrations.
    integrations.add(WidgetsFlutterBindingIntegration());

    // Will catch any errors that may occur in the Flutter framework itself.
    integrations.add(FlutterErrorIntegration());

    // This tracks Flutter application events, such as lifecycle events.
    integrations.add(WidgetsBindingIntegration());

    // The ordering here matters, as we'd like to first start the native integration.
    // That allow us to send events to the network and then the Flutter integrations.
    // Flutter Web doesn't need that, only Android and iOS.
    if (options.platformChecker.hasNativeIntegration) {
      integrations.add(NativeSdkIntegration(channel));
    }

    // Will enrich events with device context, native packages and integrations
    if (options.platformChecker.platform.isIOS || options.platformChecker.platform.isMacOS) {
      integrations.add(LoadContextsIntegration(channel));
    }

    if (options.platformChecker.platform.isAndroid) {
      integrations.add(LoadAndroidImageListIntegration(channel));
    }

    // This is an Integration because we want to execute it after all the
    // error handlers are in place. Calling a MethodChannel might result
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

/// Package info loader.
Future<PackageInfo> _loadPackageInfo() async {
  return await PackageInfo.fromPlatform();
}
