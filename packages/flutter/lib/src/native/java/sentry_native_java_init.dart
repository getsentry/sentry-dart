part of 'sentry_native_java.dart';

const _flutterSdkName = 'sentry.dart.flutter';

@internal
const androidSdkName = 'sentry.java.android.flutter';

@internal
const nativeSdkName = 'sentry.native.android.flutter';

/// Initializes the Sentry Android SDK.
void initSentryAndroid({
  required Hub hub,
  required SentryFlutterOptions options,
  required SentryNativeJava owner,
}) {
  final replayCallbacks = createReplayRecorderCallbacks(
    options: options,
    hub: hub,
    owner: owner,
  );

  final beforeSendReplayCallback = createBeforeSendReplayCallback(options);
  final beforeSendEventCallback = createBeforeSendCallback();

  using((arena) {
    final context = native.SentryFlutterPlugin.getApplicationContext()
      ?..releasedBy(arena);
    if (context == null) {
      options.log(SentryLevel.error,
          'Failed to initialize Sentry Android, application context is null.');
      return;
    }

    final optionsConfiguration = native.Sentry$OptionsConfiguration.implement(
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

          replayCallbacks.use((cb) {
            native.SentryFlutterPlugin.setupReplay(androidOptions, cb);
          });
        },
      ),
    );

    optionsConfiguration.use((cb) {
      native.SentryAndroid.init$2(context, cb);
    });
  });
}

/// Builds the general beforeSend callback to tag events with origin/environment
/// based on SDK name.
native.SentryOptions$BeforeSendCallback createBeforeSendCallback() {
  return native.SentryOptions$BeforeSendCallback.implement(
    native.$SentryOptions$BeforeSendCallback(
      execute: (sentryEvent, hint) {
        using((arena) {
          final sdk = sentryEvent.getSdk()?..releasedBy(arena);
          if (sdk == null) return;

          final originKey = 'event.origin'.toJString()..releasedBy(arena);
          final environmentKey = 'event.environment'.toJString()
            ..releasedBy(arena);

          void setTagPair(String origin, String environment) {
            final originVal = origin.toJString()..releasedBy(arena);
            final envVal = environment.toJString()..releasedBy(arena);
            sentryEvent.setTag(originKey, originVal);
            sentryEvent.setTag(environmentKey, envVal);
          }

          switch (sdk.getName().toDartString(releaseOriginal: true)) {
            case _flutterSdkName:
              setTagPair('flutter', 'dart');
              break;
            case androidSdkName:
              setTagPair('android', 'java');
              break;
            case nativeSdkName:
              setTagPair('android', 'native');
              break;
            default:
              break;
          }
        });
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
        using((arena) {
          final data = hint
              .getReplayRecording()
              ?.getPayload()
              ?.use((l) => l.firstOrNull)
            ?..releasedBy(arena);
          if (data is native.$RRWebOptionsEvent$Type) {
            final payload = data
                ?.as(native.RRWebOptionsEvent.type)
                .getOptionsPayload()
              ?..releasedBy(arena);
            payload?.removeWhere((key, value) {
              final shouldRemove =
                  key?.toDartString(releaseOriginal: true).contains('mask') ??
                      false;
              value?.release(); // release the materialized value handle
              return shouldRemove;
            });

            final jMap = dartToJMap(options.privacy.toJson());
            payload?.addAll(jMap);
            jMap.release();
          }
        });
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
        final replayId =
            SentryId.fromId(replayIdString.toDartString(releaseOriginal: true));

        owner._replayId = replayId;
        owner._nativeReplay =
            native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
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
  using((arena) {
    androidOptions.setDsn(options.dsn?.toJString()?..releasedBy(arena));
    androidOptions.setDebug(options.debug);
    androidOptions
        .setEnvironment(options.environment?.toJString()?..releasedBy(arena));
    androidOptions.setRelease(options.release?.toJString()?..releasedBy(arena));
    androidOptions.setDist(options.dist?.toJString()?..releasedBy(arena));
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
    androidOptions
        .setEnableActivityLifecycleBreadcrumbs(enableNativeBreadcrumbs);
    androidOptions.setEnableAppLifecycleBreadcrumbs(enableNativeBreadcrumbs);
    androidOptions.setEnableSystemEventBreadcrumbs(enableNativeBreadcrumbs);
    androidOptions.setEnableAppComponentBreadcrumbs(enableNativeBreadcrumbs);
    androidOptions.setEnableUserInteractionBreadcrumbs(enableNativeBreadcrumbs);

    androidOptions.setMaxBreadcrumbs(options.maxBreadcrumbs);
    androidOptions.setMaxCacheItems(options.maxCacheItems);
    if (options.debug) {
      final levelName = options.diagnosticLevel.name.toUpperCase().toJString()
        ..releasedBy(arena);
      final androidLevel = native.SentryLevel.valueOf(levelName)
        ?..releasedBy(arena);
      if (androidLevel != null) {
        androidOptions.setDiagnosticLevel(androidLevel);
      }
    }
    androidOptions.setSendDefaultPii(options.sendDefaultPii);
    androidOptions.setEnableScopeSync(options.enableNdkScopeSync);
    androidOptions
        .setProguardUuid(options.proguardUuid?.toJString()?..releasedBy(arena));
    androidOptions.setEnableSpotlight(options.spotlight.enabled);
    androidOptions.setSpotlightConnectionUrl(
        options.spotlight.url?.toJString()?..releasedBy(arena));

    if (!options.enableNativeCrashHandling) {
      androidOptions.setEnableUncaughtExceptionHandler(false);
      androidOptions.setAnrEnabled(false);
    }

    androidOptions.setSendClientReports(options.sendClientReports);
    androidOptions.setMaxAttachmentSize(options.maxAttachmentSize);
    androidOptions
        .setConnectionTimeoutMillis(options.connectionTimeout.inMilliseconds);
    androidOptions.setReadTimeoutMillis(options.readTimeout.inMilliseconds);

    final sentryProxy = native.SentryOptions$Proxy()..releasedBy(arena);
    sentryProxy.setHost(options.proxy?.host?.toJString()?..releasedBy(arena));
    sentryProxy.setPort(
        options.proxy?.port?.toString().toJString()?..releasedBy(arena));
    sentryProxy.setUser(options.proxy?.user?.toJString()?..releasedBy(arena));
    sentryProxy.setPass(options.proxy?.pass?.toJString()?..releasedBy(arena));
    final type = options.proxy?.type.name.toUpperCase().toJString()
      ?..releasedBy(arena);
    if (type != null) {
      sentryProxy.setType(native.Proxy$Type.valueOf(type)?..releasedBy(arena));
    }
    androidOptions.setProxy(sentryProxy);

    native.SdkVersion? sdkVersion = androidOptions.getSdkVersion()
      ?..releasedBy(arena);
    if (sdkVersion == null) {
      sdkVersion = native.SdkVersion(
        androidSdkName.toJString()..releasedBy(arena),
        native.BuildConfig.VERSION_NAME!..releasedBy(arena),
      )..releasedBy(arena);
    } else {
      sdkVersion.setName(androidSdkName.toJString()..releasedBy(arena));
    }
    androidOptions.setSentryClientName(
        '$androidSdkName/${native.BuildConfig.VERSION_NAME}'.toJString()
          ..releasedBy(arena));
    androidOptions
        .setNativeSdkName(nativeSdkName.toJString()..releasedBy(arena));
    for (final integration in options.sdk.integrations) {
      sdkVersion.addIntegration(integration.toJString()..releasedBy(arena));
    }
    for (final package in options.sdk.packages) {
      sdkVersion.addPackage(
        package.name.toJString()..releasedBy(arena),
        package.version.toJString()..releasedBy(arena),
      );
    }

    beforeSend.use((cb) {
      androidOptions.setBeforeSend(cb);
    });

    final sessionReplay = androidOptions.getSessionReplay()..releasedBy(arena);
    switch (options.replay.quality) {
      case SentryReplayQuality.low:
        sessionReplay.setQuality(
            native.SentryReplayOptions$SentryReplayQuality.LOW
              ..releasedBy(arena));
        break;
      case SentryReplayQuality.high:
        sessionReplay.setQuality(
            native.SentryReplayOptions$SentryReplayQuality.HIGH
              ..releasedBy(arena));
        break;
      default:
        sessionReplay.setQuality(
            native.SentryReplayOptions$SentryReplayQuality.MEDIUM
              ..releasedBy(arena));
    }
    sessionReplay.setSessionSampleRate(
        options.replay.sessionSampleRate?.toJDouble()?..releasedBy(arena));
    sessionReplay.setOnErrorSampleRate(
        options.replay.onErrorSampleRate?.toJDouble()?..releasedBy(arena));

    sessionReplay.setTrackConfiguration(false);
    beforeSendReplay.use((cb) {
      androidOptions.setBeforeSendReplay(cb);
    });
    sessionReplay.setSdkVersion(sdkVersion);
  });
}
