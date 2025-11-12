part of 'sentry_native_cocoa.dart';

@internal
const cocoaSdkName = 'sentry.cocoa.flutter';

/// Initializes the Sentry Cocoa SDK and sets up Replay bridging.
void initSentryCocoa({
  required Hub hub,
  required SentryFlutterOptions options,
  required SentryNativeCocoa owner,
}) {
  cocoa.SentrySDK.startWithConfigureOptions(
    cocoa.ObjCBlock_ffiVoid_SentryOptions.fromFunction(
      (cocoa.SentryOptions cocoaOptions) {
        configureCocoaOptions(
          cocoaOptions: cocoaOptions,
          options: options,
        );
      },
    ),
  );

  // Mimic didBecomeActiveNotification for session, OOM tracking, replays, etc.
  cocoa.SentryFlutterPlugin.setupHybridSdkNotifications();

  cocoa.SentryFlutterPlugin.setupReplay(
    createReplayCaptureCallback(
      options: options,
      hub: hub,
      owner: owner,
    ),
    tags: _dartToNSDictionary(options.privacy.toJson()),
  );
}

/// Maps Dart-layer options to Sentry Cocoa options, including Replay settings
/// and native beforeSend configuration.
void configureCocoaOptions({
  required cocoa.SentryOptions cocoaOptions,
  required SentryFlutterOptions options,
}) {
  cocoaOptions.dsn = options.dsn?.toNSString();
  cocoaOptions.debug = options.debug;
  if (options.debug) {
    cocoaOptions.diagnosticLevel =
        cocoa.SentryLevel.fromValue(options.diagnosticLevel.ordinal);
  }
  if (options.environment != null) {
    cocoaOptions.environment = options.environment!.toNSString();
  }
  if (options.release != null) {
    cocoaOptions.releaseName = options.release!.toNSString();
  }
  if (options.dist != null) {
    cocoaOptions.dist = options.dist!.toNSString();
  }
  cocoaOptions.sendDefaultPii = options.sendDefaultPii;
  cocoaOptions.sendClientReports = options.sendClientReports;
  cocoaOptions.attachStacktrace = options.attachStacktrace;
  cocoaOptions.enableWatchdogTerminationTracking =
      options.enableWatchdogTerminationTracking;
  cocoaOptions.enableAutoSessionTracking = options.enableAutoSessionTracking;
  cocoaOptions.sessionTrackingIntervalMillis =
      options.autoSessionTrackingInterval.inMilliseconds;
  cocoaOptions.enableAutoBreadcrumbTracking =
      options.enableAutoNativeBreadcrumbs;
  cocoaOptions.enableCrashHandler = options.enableNativeCrashHandling;
  cocoaOptions.maxBreadcrumbs = options.maxBreadcrumbs;
  cocoaOptions.maxCacheItems = options.maxCacheItems;
  cocoaOptions.maxAttachmentSize = options.maxAttachmentSize;
  cocoaOptions.enableNetworkBreadcrumbs = options.recordHttpBreadcrumbs;
  cocoaOptions.enableCaptureFailedRequests = options.captureFailedRequests;
  cocoaOptions.enableAppHangTracking = options.enableAppHangTracking;
  cocoaOptions.appHangTimeoutInterval =
      options.appHangTimeoutInterval.inSeconds.toDouble();
  cocoaOptions.enableSpotlight = options.spotlight.enabled;
  if (options.spotlight.url != null) {
    cocoaOptions.spotlightUrl = options.spotlight.url!.toNSString();
  }

  cocoa.SentryFlutterPlugin.setReplayOptions(
    cocoaOptions,
    quality: options.replay.quality.level,
    sessionSampleRate: options.replay.sessionSampleRate ?? 0,
    onErrorSampleRate: options.replay.onErrorSampleRate ?? 0,
    sdkName: options.sdk.name.toNSString(),
    sdkVersion: options.sdk.version.toNSString(),
  );

  if (options.proxy != null) {
    final host = options.proxy!.host?.toNSString();
    final port = options.proxy!.port?.toNSNumber();
    final type = options.proxy!.type
        .toString()
        .split('.')
        .last
        .toUpperCase()
        .toNSString();
    if (host != null && port != null) {
      cocoa.SentryFlutterPlugin.setProxyOptions(
        cocoaOptions,
        user: options.proxy!.user?.toNSString(),
        pass: options.proxy!.pass?.toNSString(),
        host: host,
        port: port,
        type: type,
      );
    }
  }

  if (options.enableAutoPerformanceTracing) {
    cocoa.SentryFlutterPlugin.setAutoPerformanceFeatures();
  }

  final version = cocoa.PrivateSentrySDKOnly.getSdkVersionString();
  cocoa.PrivateSentrySDKOnly.setSdkName(
    cocoaSdkName.toNSString(),
    andVersionString: version,
  );

  // We currently cannot implement beforeSend in Dart.
  // Blocks created using fromFunction must be invoked on the owner isolate's thread, otherwise they will crash
  // There is no guarantee that this is the case for beforeSend and in local tests it consistently crashed.
  // See https://github.com/dart-lang/native/blob/main/pkgs/ffigen/doc/objc_threading.md
  final packages =
      options.sdk.packages.map((e) => e.toJson()).toList(growable: false);
  cocoa.SentryFlutterPlugin.setBeforeSend(
    cocoaOptions,
    packages: _dartToNSArray(packages),
    integrations: _dartToNSArray(options.sdk.integrations),
  );
}

/// Builds the Replay capture callback that bridges native replay requests
/// to the Dart-side screenshot recorder.
cocoa.DartSentryReplayCaptureCallback createReplayCaptureCallback({
  required SentryFlutterOptions options,
  required Hub hub,
  required SentryNativeCocoa owner,
}) {
  // listener can be invoked from any thread and is therefore safe unlike fromFunction
  return cocoa.ObjCBlock_ffiVoid_NSString_bool_ffiVoidobjcObjCObject.listener(
    (NSString? replayIdPtr,
        bool replayIsBuffering,
        objc.ObjCBlock<ffi.Void Function(ffi.Pointer<objc.ObjCObject>?)>
            result) {
      owner._replayRecorder ??= CocoaReplayRecorder(options);

      final replayIdStr = replayIdPtr?.toDartString();
      final replayId =
          replayIdStr == null ? null : SentryId.fromId(replayIdStr);

      if (owner._replayId != replayId) {
        owner._replayId = replayId;
        hub.configureScope((s) {
          // Only set replay ID on scope if not buffering (active session mode)
          // ignore: invalid_use_of_internal_member
          s.replayId = !replayIsBuffering ? replayId : null;
        });
      }

      owner._replayRecorder!.captureScreenshot().then((data) {
        if (data == null) {
          result(null);
          return;
        }
        final nsDict = _dartToNSDictionary(Map<String, dynamic>.from(data));
        result(nsDict);
      }).catchError((Object exception, StackTrace stackTrace) {
        options.log(
          SentryLevel.error,
          'FFI: Failed to capture replay screenshot',
          exception: exception,
          stackTrace: stackTrace,
        );
        result(null);
      });
    },
  );
}
