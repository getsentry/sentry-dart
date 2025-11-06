part of 'sentry_native_java.dart';

/// Initializes the Sentry Android SDK.
Future<void> initSentryAndroid({
  required Hub hub,
  required SentryFlutterOptions options,
  required SentryNativeJava owner,
}) async {
  final replayCallbacks = createReplayRecorderCallbacks(
    options: options,
    hub: hub,
    owner: owner,
  );

  final beforeSendReplayCallback = createBeforeSendReplayCallback(options);
  final beforeSendEventCallback = createBeforeSendCallback();

  final context = native.SentryFlutterPlugin.getApplicationContext()!;
  native.SentryAndroid.init$2(
    context,
    native.Sentry$OptionsConfiguration.implement(
      native.$Sentry$OptionsConfiguration(
        T: native.SentryAndroidOptions.nullableType,
        configure: (native.SentryAndroidOptions? androidOptions) {
          if (androidOptions == null) return;

          configureAndroidOptions(
            androidOptions: androidOptions,
            options: options,
            beforeSend: beforeSendEventCallback,
            beforeSendReplay: beforeSendReplayCallback,
          );

          native.SentryFlutterPlugin.Companion
              .setupReplayJni(androidOptions, replayCallbacks);
        },
      ),
    ),
  );
}

/// Builds the general beforeSend callback to tag events with origin/environment
/// based on SDK name.
native.SentryOptions$BeforeSendCallback createBeforeSendCallback() {
  return native.SentryOptions$BeforeSendCallback.implement(
    native.$SentryOptions$BeforeSendCallback(
      execute: (sentryEvent, hint) {
        final sdk = sentryEvent.getSdk();
        if (sdk != null) {
          switch (sdk.getName().toDartString()) {
            case flutterSdkName:
              sentryEvent.setTag(
                  'event.origin'.toJString(), 'flutter'.toJString());
              sentryEvent.setTag(
                  'event.environment'.toJString(), 'dart'.toJString());
              break;
            case androidSdkName:
              sentryEvent.setTag(
                  'event.origin'.toJString(), 'android'.toJString());
              sentryEvent.setTag(
                  'event.environment'.toJString(), 'java'.toJString());
              break;
            case nativeSdkName:
              sentryEvent.setTag(
                  'event.origin'.toJString(), 'android'.toJString());
              sentryEvent.setTag(
                  'event.environment'.toJString(), 'native'.toJString());
              break;
            default:
              break;
          }
        }
        return sentryEvent;
      },
    ),
  );
}

/// Builds the beforeSendReplay callback to override rrweb masking options
/// using Dart-layer privacy configuration.
native.SentryOptions$BeforeSendReplayCallback createBeforeSendReplayCallback(
    SentryFlutterOptions options) {
  return native.SentryOptions$BeforeSendReplayCallback.implement(
    native.$SentryOptions$BeforeSendReplayCallback(
      execute: (sentryReplayEvent, hint) {
        final data = hint.getReplayRecording()?.getPayload()?.firstOrNull;
        if (data is native.$RRWebOptionsEvent$Type) {
          final payload =
              data?.as(native.RRWebOptionsEvent.type).getOptionsPayload();
          payload?.removeWhere((key, value) =>
              key?.toDartString(releaseOriginal: true).contains('mask') ??
              false);

          using((arena) {
            payload?.addAll({
              'maskAllText'.toJString():
                  options.privacy.maskAllText.toJBoolean(),
              'maskAllImages'.toJString():
                  options.privacy.maskAllImages.toJBoolean(),
              'maskAssetImages'.toJString():
                  options.privacy.maskAssetImages.toJBoolean(),
              if (options.privacy.userMaskingRules.isNotEmpty)
                'maskingRules'.toJString(): _dartToJList(
                    options.privacy.userMaskingRules
                        .map((rule) => '${rule.name}: ${rule.description}')
                        .toList(growable: false),
                    arena),
            });
          });
        }
        return sentryReplayEvent;
      },
    ),
  );
}

/// Builds replay recorder callbacks that bridge between native replay lifecycle
/// and the Dart-side recorder instance.
native.ReplayRecorderCallbacks? createReplayRecorderCallbacks({
  required SentryFlutterOptions options,
  required Hub hub,
  required SentryNativeJava owner,
}) {
  if (!options.replay.isEnabled) return null;

  return native.ReplayRecorderCallbacks.implement(
    native.$ReplayRecorderCallbacks(
      replayStarted: (JString replayIdString, bool replayIsBuffering) async {
        final replayId = SentryId.fromId(replayIdString.toDartString());

        owner._replayId = replayId;
        owner._nativeReplay = native.SentryFlutterPlugin.Companion
            .privateSentryGetReplayIntegration();
        owner._replayRecorder = AndroidReplayRecorder.factory(options);
        await owner._replayRecorder!.start();
        hub.configureScope((s) {
          // ignore: invalid_use_of_internal_member
          s.replayId = !replayIsBuffering ? replayId : null;
        });
      },
      replayResumed: () async {
        await owner._replayRecorder?.resume();
      },
      replayPaused: () async {
        await owner._replayRecorder?.pause();
      },
      replayStopped: () async {
        hub.configureScope((s) {
          // ignore: invalid_use_of_internal_member
          s.replayId = null;
        });

        final future = owner._replayRecorder?.stop();
        owner._replayRecorder = null;
        await future;
      },
      replayReset: () {
        // ignored
      },
      replayConfigChanged: (int width, int height, int frameRate) async {
        final config = ScheduledScreenshotRecorderConfig(
          width: width.toDouble(),
          height: height.toDouble(),
          frameRate: frameRate,
        );

        await owner._replayRecorder?.onConfigurationChanged(config);
      },
    ),
  );
}

/// Maps Dart-layer options into `SentryAndroidOptions`, including base SDK
/// configuration and Replay-specific settings.
void configureAndroidOptions({
  required native.SentryAndroidOptions androidOptions,
  required SentryFlutterOptions options,
  required native.SentryOptions$BeforeSendCallback beforeSend,
  required native.SentryOptions$BeforeSendReplayCallback beforeSendReplay,
}) {
  androidOptions.setDsn(options.dsn?.toJString());
  androidOptions.setDebug(options.debug);
  androidOptions.setEnvironment(options.environment?.toJString());
  androidOptions.setRelease(options.release?.toJString());
  androidOptions.setDist(options.dist?.toJString());
  androidOptions
      .setEnableAutoSessionTracking(options.enableAutoSessionTracking);
  androidOptions.setSessionTrackingIntervalMillis(
      options.autoSessionTrackingInterval.inMilliseconds);
  androidOptions
      .setAnrTimeoutIntervalMillis(options.anrTimeoutInterval.inMilliseconds);
  androidOptions.setAnrEnabled(options.anrEnabled);
  androidOptions.setAttachThreads(options.attachThreads);
  androidOptions.setAttachStacktrace(options.attachStacktrace);

  final enableNativeBreadcrumbs = options.enableAutoNativeBreadcrumbs;
  androidOptions.setEnableActivityLifecycleBreadcrumbs(enableNativeBreadcrumbs);
  androidOptions.setEnableAppLifecycleBreadcrumbs(enableNativeBreadcrumbs);
  androidOptions.setEnableSystemEventBreadcrumbs(enableNativeBreadcrumbs);
  androidOptions.setEnableAppComponentBreadcrumbs(enableNativeBreadcrumbs);
  androidOptions.setEnableUserInteractionBreadcrumbs(enableNativeBreadcrumbs);

  androidOptions.setMaxBreadcrumbs(options.maxBreadcrumbs);
  androidOptions.setMaxCacheItems(options.maxCacheItems);
  if (options.debug) {
    final androidLevel = native.SentryLevel.valueOf(
        options.diagnosticLevel.name.toUpperCase().toJString());
    androidOptions.setDiagnosticLevel(androidLevel);
  }
  androidOptions.setSendDefaultPii(options.sendDefaultPii);
  androidOptions.setEnableScopeSync(options.enableNdkScopeSync);
  androidOptions.setProguardUuid(options.proguardUuid?.toJString());
  androidOptions.setEnableSpotlight(options.spotlight.enabled);
  androidOptions.setSpotlightConnectionUrl(options.spotlight.url?.toJString());

  if (!options.enableNativeCrashHandling) {
    androidOptions.setEnableUncaughtExceptionHandler(false);
    androidOptions.setAnrEnabled(false);
  }

  androidOptions.setSendClientReports(options.sendClientReports);
  androidOptions.setMaxAttachmentSize(options.maxAttachmentSize);
  androidOptions
      .setConnectionTimeoutMillis(options.connectionTimeout.inMilliseconds);
  androidOptions.setReadTimeoutMillis(options.readTimeout.inMilliseconds);

  native.SentryFlutterPlugin.Companion.setProxy(
    androidOptions,
    options.proxy?.user?.toJString(),
    options.proxy?.pass?.toJString(),
    options.proxy?.host?.toJString(),
    options.proxy?.port?.toString().toJString(),
    options.proxy?.type.toString().split('.').last.toUpperCase().toJString(),
  );

  native.SdkVersion? sdkVersion = androidOptions.getSdkVersion();
  if (sdkVersion == null) {
    sdkVersion = native.SdkVersion(
      androidSdkName.toJString(),
      native.BuildConfig.VERSION_NAME!,
    );
  } else {
    sdkVersion.setName(androidSdkName.toJString());
  }
  for (final integration in options.sdk.integrations) {
    sdkVersion.addIntegration(integration.toJString());
  }
  for (final package in options.sdk.packages) {
    sdkVersion.addPackage(
      package.name.toJString(),
      package.version.toJString(),
    );
  }

  androidOptions.setBeforeSend(beforeSend);

  switch (options.replay.quality) {
    case SentryReplayQuality.low:
      androidOptions
          .getSessionReplay()
          .setQuality(native.SentryReplayOptions$SentryReplayQuality.LOW);
      break;
    case SentryReplayQuality.high:
      androidOptions
          .getSessionReplay()
          .setQuality(native.SentryReplayOptions$SentryReplayQuality.HIGH);
      break;
    default:
      androidOptions
          .getSessionReplay()
          .setQuality(native.SentryReplayOptions$SentryReplayQuality.MEDIUM);
  }
  androidOptions
      .getSessionReplay()
      .setSessionSampleRate(options.replay.sessionSampleRate?.toJDouble());
  androidOptions
      .getSessionReplay()
      .setOnErrorSampleRate(options.replay.onErrorSampleRate?.toJDouble());

  androidOptions.getSessionReplay().setTrackConfiguration(false);
  androidOptions.setBeforeSendReplay(beforeSendReplay);
  androidOptions.getSessionReplay().setSdkVersion(sdkVersion);
}
