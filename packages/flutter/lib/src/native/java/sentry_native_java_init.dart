part of 'sentry_native_java.dart';

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

  using((arena) {
    final context = native.SentryFlutterPlugin.getApplicationContext()
      ?..releasedBy(arena);
    if (context == null) {
      internalLogger.error(
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

/// Builds the beforeSendReplay callback to override rrweb masking options
/// using Dart-layer privacy configuration.
native.SentryOptions$BeforeSendReplayCallback createBeforeSendReplayCallback(
    SentryFlutterOptions options) {
  return native.SentryOptions$BeforeSendReplayCallback.implement(
    native.$SentryOptions$BeforeSendReplayCallback(
      execute: (sentryReplayEvent, hint) {
        try {
          using((arena) {
            final replayRecording = hint.getReplayRecording()
              ?..releasedBy(arena);
            final data = replayRecording?.getPayload()?.use(
                  (payload) => payload.firstOrNull,
                )?..releasedBy(arena);
            if (data?.isA(native.RRWebOptionsEvent.type) ?? false) {
              final optionsEvent = data!.as(native.RRWebOptionsEvent.type)
                ..releasedBy(arena);
              final payload = optionsEvent.getOptionsPayload()
                ..releasedBy(arena);

              final keys = payload.keys..releasedBy(arena);
              final iterator = keys.iterator..releasedBy(arena);
              final keysToRemove = <JString>[];
              while (iterator.moveNext()) {
                final key = iterator.current?..releasedBy(arena);
                if (key?.toDartString().contains('mask') ?? false) {
                  keysToRemove.add(key!);
                }
              }

              for (final key in keysToRemove) {
                payload.remove(key)?.releasedBy(arena);
              }

              final jMap = dartToJMap(options.privacy.toJson())
                ..releasedBy(arena);
              payload.addAll(jMap);
            }
          });
          return sentryReplayEvent;
        } finally {
          hint.release();
        }
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
        owner._setNativeReplay(
          native.SentryFlutterPlugin.privateSentryGetReplayIntegration(),
        );
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
        owner._setNativeReplay(null);
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
  required native.SentryOptions$BeforeSendReplayCallback beforeSendReplay,
}) {
  using((arena) {
    androidOptions.setDsn(options.dsn?.toJString()?..releasedBy(arena));
    androidOptions
        .setSampleRate(options.sampleRate?.toJDouble()?..releasedBy(arena));
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
    androidOptions.setTombstoneEnabled(options.enableTombstone);
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
    // When trace sync is enabled, Dart is the source of truth for propagation
    // context and pushes it to native via setTrace. Disable native auto
    // generation so it doesn't overwrite the Dart-provided trace ID.
    if (options.enableNativeTraceSync) {
      androidOptions.setEnableAutoTraceIdGeneration(false);
    }
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
    androidOptions.setStrictTraceContinuation(options.strictTraceContinuation);
    androidOptions
        // ignore: invalid_use_of_internal_member
        .setOrgId(options.effectiveOrgId?.toJString()?..releasedBy(arena));
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
    final versionName = native.BuildConfig.VERSION_NAME!..releasedBy(arena);
    final versionNameString = versionName.toDartString();
    if (sdkVersion == null) {
      sdkVersion = native.SdkVersion(
        androidSdkName.toJString()..releasedBy(arena),
        versionName,
      )..releasedBy(arena);
    } else {
      sdkVersion.setName(androidSdkName.toJString()..releasedBy(arena));
    }
    androidOptions.setSentryClientName(
        '$androidSdkName/$versionNameString'.toJString()..releasedBy(arena));
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

    native.SentryFlutterPlugin.setupBeforeSend(androidOptions);

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

    if (options.networkDetailAllowUrls.isNotEmpty) {
      sessionReplay.setNetworkDetailAllowUrls(
          dartToJStringList(options.networkDetailAllowUrls)..releasedBy(arena));
      sessionReplay.setNetworkDetailDenyUrls(
          dartToJStringList(options.networkDetailDenyUrls)..releasedBy(arena));
      // Custom header names and bodies may contain PII, so they mirror the
      // sendDefaultPii gate used on the Dart side.
      final extraHeaders = options.sendDefaultPii;
      sessionReplay.setNetworkRequestHeaders(dartToJStringList(
          extraHeaders ? options.networkRequestHeaders : const [])
        ..releasedBy(arena));
      sessionReplay.setNetworkResponseHeaders(dartToJStringList(
          extraHeaders ? options.networkResponseHeaders : const [])
        ..releasedBy(arena));
      sessionReplay.setNetworkCaptureBodies(
          options.networkCaptureBodies && options.sendDefaultPii);
    }

    sessionReplay.setTrackConfiguration(false);
    beforeSendReplay.use((cb) {
      androidOptions.setBeforeSendReplay(cb);
    });
    sessionReplay.setSdkVersion(sdkVersion);
  });
}
