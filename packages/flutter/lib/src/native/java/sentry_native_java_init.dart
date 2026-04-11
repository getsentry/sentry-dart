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
    final context = native.SentryFlutterPlugin.applicationContext
      ?..releasedBy(arena);
    if (context == null) {
      options.log(SentryLevel.error,
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
          final sdk = sentryEvent.sdk?..releasedBy(arena);
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

          switch (sdk.name.toDartString(releaseOriginal: true)) {
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
          final data = hint.replayRecording?.payload
              ?.use((l) => l.isEmpty() ? null : l.get(0))
            ?..releasedBy(arena);
          if (data != null && data.isA(native.RRWebOptionsEvent.type)) {
            final payload = data
                .as(native.RRWebOptionsEvent.type)
                .optionsPayload
              ..releasedBy(arena);
            final keysToRemove = <JString>[];
            final keys = payload.keySet()?..releasedBy(arena);
            if (keys != null) {
              final iterator = keys.iterator()!..releasedBy(arena);
              while (iterator.hasNext()) {
                final key = iterator.next();
                if (key != null) {
                  final keyStr = key.toDartString(releaseOriginal: true);
                  if (keyStr.contains('mask')) {
                    keysToRemove.add(keyStr.toJString());
                  }
                }
              }
            }
            for (final key in keysToRemove) {
              payload.remove(key)?.release();
              key.release();
            }

            final jMap = dartToJMap(options.privacy.toJson());
            payload.putAll(jMap);
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
    androidOptions.dsn = options.dsn?.toJString()?..releasedBy(arena);
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
    androidOptions.connectionTimeoutMillis =
        options.connectionTimeout.inMilliseconds;
    androidOptions.readTimeoutMillis = options.readTimeout.inMilliseconds;

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
    if (sdkVersion == null) {
      sdkVersion = native.SdkVersion(
        androidSdkName.toJString()..releasedBy(arena),
        native.BuildConfig.VERSION_NAME!..releasedBy(arena),
      )..releasedBy(arena);
    } else {
      sdkVersion.name = androidSdkName.toJString()..releasedBy(arena);
    }
    androidOptions.sentryClientName =
        '$androidSdkName/${native.BuildConfig.VERSION_NAME}'.toJString()
          ..releasedBy(arena);
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

    beforeSend.use((cb) {
      androidOptions.beforeSend = cb;
    });

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

    sessionReplay.trackConfiguration = false;
    beforeSendReplay.use((cb) {
      androidOptions.beforeSendReplay = cb;
    });
    sessionReplay.sdkVersion = sdkVersion;
  });
}
