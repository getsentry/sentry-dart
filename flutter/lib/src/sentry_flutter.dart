import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'event_processor/android_platform_exception_event_processor.dart';
import 'sentry_native.dart';
import 'sentry_native_channel.dart';

import 'flutter_enricher_event_processor.dart';
import 'integrations/debug_print_integration.dart';
import 'integrations/native_app_start_integration.dart';
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
    PlatformChecker? platformChecker,
    bool? enableNative = true,
    bool? autoInitializeNative = true,
  }) async {
    final flutterOptions = SentryFlutterOptions();

    if (platformChecker != null) {
      flutterOptions.platformChecker = platformChecker;
    }
    if (enableNative != null) {
      flutterOptions.enableNative = enableNative;
    }
    if (autoInitializeNative != null) {
      flutterOptions.autoInitializeNative = autoInitializeNative;
    }

    final nativeChannel = SentryNativeChannel(channel, flutterOptions);
    final native = SentryNative();
    native.setNativeChannel(nativeChannel);

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
      // ignore: invalid_use_of_internal_member
      options: flutterOptions,
    );
  }

  static Future<void> _initDefaultValues(
    SentryFlutterOptions options,
    MethodChannel channel,
  ) async {
    // Not all platforms have a native integration.
    if (options.isNativeIntegrationsEnabled) {
      options.transport = FileSystemTransport(channel, options);
    }

    var flutterEventProcessor =
        FlutterEnricherEventProcessor.simple(options: options);
    options.addEventProcessor(flutterEventProcessor);

    if (options.platformChecker.platform.isAndroid) {
      options
          .addEventProcessor(AndroidPlatformExceptionEventProcessor(options));
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
    if (options.isNativeIntegrationsEnabled && options.autoInitializeNative) {
      integrations.add(InitNativeSdkIntegration(channel));
    }

    // Will enrich events with device context, native packages and integrations
    if (options.enableNative &&
        !options.platformChecker.isWeb &&
        (options.platformChecker.platform.isIOS ||
            options.platformChecker.platform.isMacOS)) {
      integrations.add(LoadContextsIntegration(channel));
    }

    if (options.enableNative &&
        !options.platformChecker.isWeb &&
        options.platformChecker.platform.isAndroid) {
      integrations.add(LoadAndroidImageListIntegration(channel));
    }

    integrations.add(DebugPrintIntegration());

    // This is an Integration because we want to execute it after all the
    // error handlers are in place. Calling a MethodChannel might result
    // in errors.
    integrations.add(LoadReleaseIntegration(packageLoader));

    if (options.isNativeIntegrationsEnabled) {
      integrations.add(NativeAppStartIntegration(
        SentryNative(),
        () {
          try {
            /// Flutter >= 2.12 throws if SchedulerBinding.instance isn't initialized.
            return SchedulerBinding.instance;
          } catch (_) {}
          return null;
        },
      ));
    }
    return integrations;
  }

  /// Manually set when your app finished startup. Make sure to set
  /// [SentryFlutterOptions.autoAppStart] to false on init.
  static void setAppStartEnd(DateTime appStartEnd) {
    SentryNative().appStartEnd = appStartEnd;
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
