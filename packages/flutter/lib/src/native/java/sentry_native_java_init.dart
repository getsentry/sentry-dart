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
    final context = native.SentryFlutterPlugin.applicationContext
      ?..releasedBy(arena);
    if (context == null) {
      internalLogger.error(
          'Failed to initialize Sentry Android, application context is null.');
      return;
    }

    final optionsConfiguration = native.Sentry$OptionsConfiguration.implement(
      native.$Sentry$OptionsConfiguration<native.SentryAndroidOptions>(
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
            final replayRecording = hint.replayRecording?..releasedBy(arena);
            final data = replayRecording?.payload?.use(
              (payload) => payload.asDart().firstOrNull,
            )?..releasedBy(arena);
            if (data?.isA(native.RRWebOptionsEvent.type) ?? false) {
              final optionsEvent = data!.as(native.RRWebOptionsEvent.type)
                ..releasedBy(arena);
              final payload = optionsEvent.optionsPayload..releasedBy(arena);

              final keys = payload.keySet()!..releasedBy(arena);
              final iterator = keys.iterator()!..releasedBy(arena);
              final keysToRemove = <JString>[];
              while (iterator.hasNext()) {
                final key = iterator.next()?..releasedBy(arena);
                if (key?.toDartString().contains('mask') ?? false) {
                  keysToRemove.add(key!);
                }
              }

              for (final key in keysToRemove) {
                payload.remove(key)?.releasedBy(arena);
              }

              final jMap = dartToJMap(options.privacy.toJson())
                ..releasedBy(arena);
              payload.putAll(jMap);
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
    androidOptions.dsn = options.dsn?.toJString()?..releasedBy(arena);
    androidOptions.sampleRate = options.sampleRate?.toJDouble()
      ?..releasedBy(arena);
    androidOptions.debug = options.debug;
    androidOptions.environment = options.environment?.toJString()
      ?..releasedBy(arena);
    androidOptions.release$1 = options.release?.toJString()?..releasedBy(arena);
    androidOptions.dist = options.dist?.toJString()?..releasedBy(arena);
    androidOptions.enableAutoSessionTracking =
        options.enableAutoSessionTracking;
    androidOptions.sessionTrackingIntervalMillis =
        options.autoSessionTrackingInterval.inMilliseconds;
    androidOptions.anrTimeoutIntervalMillis =
        options.anrTimeoutInterval.inMilliseconds;
    androidOptions.anrEnabled = options.anrEnabled;
    androidOptions.tombstoneEnabled = options.enableTombstone;
    androidOptions.attachThreads = options.attachThreads;
    androidOptions.attachStacktrace = options.attachStacktrace;

    final enableNativeBreadcrumbs = options.enableAutoNativeBreadcrumbs;
    androidOptions.enableActivityLifecycleBreadcrumbs = enableNativeBreadcrumbs;
    androidOptions.enableAppLifecycleBreadcrumbs = enableNativeBreadcrumbs;
    androidOptions.enableSystemEventBreadcrumbs = enableNativeBreadcrumbs;
    androidOptions.enableAppComponentBreadcrumbs = enableNativeBreadcrumbs;
    androidOptions.enableUserInteractionBreadcrumbs = enableNativeBreadcrumbs;

    androidOptions.maxBreadcrumbs = options.maxBreadcrumbs;
    androidOptions.maxCacheItems = options.maxCacheItems;
    if (options.debug) {
      final levelName = options.diagnosticLevel.name.toUpperCase().toJString()
        ..releasedBy(arena);
      final androidLevel = native.SentryLevel.valueOf(levelName)
        ?..releasedBy(arena);
      if (androidLevel != null) {
        androidOptions.diagnosticLevel = androidLevel;
      }
    }
    androidOptions.sendDefaultPii = options.sendDefaultPii;
    androidOptions.enableScopeSync = options.enableNdkScopeSync;
    // When trace sync is enabled, Dart is the source of truth for propagation
    // context and pushes it to native via setTrace. Disable native auto
    // generation so it doesn't overwrite the Dart-provided trace ID.
    if (options.enableNativeTraceSync) {
      androidOptions.enableAutoTraceIdGeneration = false;
    }
    androidOptions.proguardUuid = options.proguardUuid?.toJString()
      ?..releasedBy(arena);
    androidOptions.enableSpotlight = options.spotlight.enabled;
    androidOptions.spotlightConnectionUrl = options.spotlight.url?.toJString()
      ?..releasedBy(arena);

    if (!options.enableNativeCrashHandling) {
      androidOptions.enableUncaughtExceptionHandler = false;
      androidOptions.anrEnabled = false;
    }

    androidOptions.sendClientReports = options.sendClientReports;
    androidOptions.maxAttachmentSize = options.maxAttachmentSize;
    androidOptions.strictTraceContinuation = options.strictTraceContinuation;
    androidOptions
        // ignore: invalid_use_of_internal_member
        .orgId = options.effectiveOrgId?.toJString()?..releasedBy(arena);
    androidOptions.connectionTimeoutMillis =
        options.connectionTimeout.inMilliseconds;
    androidOptions.readTimeoutMillis = options.readTimeout.inMilliseconds;

    final logs = androidOptions.logs..releasedBy(arena);
    logs.enabled = true;
    final metrics = androidOptions.metrics..releasedBy(arena);
    metrics.enabled = true;

    final sentryProxy = native.SentryOptions$Proxy()..releasedBy(arena);
    sentryProxy.host = options.proxy?.host?.toJString()?..releasedBy(arena);
    sentryProxy.port = options.proxy?.port?.toString().toJString()
      ?..releasedBy(arena);
    sentryProxy.user = options.proxy?.user?.toJString()?..releasedBy(arena);
    sentryProxy.pass = options.proxy?.pass?.toJString()?..releasedBy(arena);
    final type = options.proxy?.type.name.toUpperCase().toJString()
      ?..releasedBy(arena);
    if (type != null) {
      sentryProxy.type$1 = native.Proxy$Type.valueOf(type)?..releasedBy(arena);
    }
    androidOptions.proxy = sentryProxy;

    native.SdkVersion? sdkVersion = androidOptions.sdkVersion
      ?..releasedBy(arena);
    final versionName = native.BuildConfig.VERSION_NAME!..releasedBy(arena);
    final versionNameString = versionName.toDartString();
    if (sdkVersion == null) {
      sdkVersion = native.SdkVersion(
        androidSdkName.toJString()..releasedBy(arena),
        versionName,
      )..releasedBy(arena);
    } else {
      sdkVersion.name = androidSdkName.toJString()..releasedBy(arena);
    }
    androidOptions.sentryClientName =
        '$androidSdkName/$versionNameString'.toJString()..releasedBy(arena);
    androidOptions.nativeSdkName = nativeSdkName.toJString()..releasedBy(arena);
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

    final sessionReplay = androidOptions.sessionReplay..releasedBy(arena);
    switch (options.replay.quality) {
      case SentryReplayQuality.low:
        sessionReplay.quality = native
            .SentryReplayOptions$SentryReplayQuality.LOW
          ..releasedBy(arena);
        break;
      case SentryReplayQuality.high:
        sessionReplay.quality = native
            .SentryReplayOptions$SentryReplayQuality.HIGH
          ..releasedBy(arena);
        break;
      default:
        sessionReplay.quality = native
            .SentryReplayOptions$SentryReplayQuality.MEDIUM
          ..releasedBy(arena);
    }
    sessionReplay.sessionSampleRate =
        options.replay.sessionSampleRate?.toJDouble()?..releasedBy(arena);
    sessionReplay.onErrorSampleRate =
        options.replay.onErrorSampleRate?.toJDouble()?..releasedBy(arena);

    if (options.replay.networkDetailAllowUrls.isNotEmpty) {
      sessionReplay.networkDetailAllowUrls =
          dartToJStringList(options.replay.networkDetailAllowUrls)
            ..releasedBy(arena);
      sessionReplay.networkDetailDenyUrls =
          dartToJStringList(options.replay.networkDetailDenyUrls)
            ..releasedBy(arena);
      // Custom header names and bodies may contain PII, so they mirror the
      // sendDefaultPii gate used on the Dart side.
      final extraHeaders = options.sendDefaultPii;
      sessionReplay.networkRequestHeaders = dartToJStringList(
          extraHeaders ? options.replay.networkRequestHeaders : const [])
        ..releasedBy(arena);
      sessionReplay.networkResponseHeaders = dartToJStringList(
          extraHeaders ? options.replay.networkResponseHeaders : const [])
        ..releasedBy(arena);
      sessionReplay.networkCaptureBodies =
          options.replay.networkCaptureBodies && options.sendDefaultPii;
    }

    sessionReplay.trackConfiguration = false;
    beforeSendReplay.use((cb) {
      androidOptions.beforeSendReplay = cb;
    });
    sessionReplay.sdkVersion = sdkVersion;
  });
}
