import 'dart:collection';
import 'package:meta/meta.dart';

import '../protocol.dart';
import 'sentry_feedback.dart';
import '../utils/type_safe_map_access.dart';

/// The context interfaces provide additional context data.
///
/// Typically this is data related to the Device, OS, Runtime, App,
/// Browser, GPU and State context.
///
/// See also: https://develop.sentry.dev/sdk/event-payloads/contexts/.
class Contexts extends MapView<String, dynamic> {
  Contexts({
    SentryDevice? device,
    SentryOperatingSystem? operatingSystem,
    List<SentryRuntime>? runtimes,
    SentryApp? app,
    SentryBrowser? browser,
    SentryGpu? gpu,
    SentryCulture? culture,
    SentryTraceContext? trace,
    SentryResponse? response,
    SentryFeedback? feedback,
    SentryFeatureFlags? flags,
  }) : super({
          SentryDevice.type: device,
          SentryOperatingSystem.type: operatingSystem,
          SentryRuntime.listType: List<SentryRuntime>.from(runtimes ?? []),
          SentryApp.type: app,
          SentryBrowser.type: browser,
          SentryGpu.type: gpu,
          SentryCulture.type: culture,
          SentryTraceContext.type: trace,
          SentryResponse.type: response,
          SentryFeedback.type: feedback,
          SentryFeatureFlags.type: flags,
        });

  /// Deserializes [Contexts] from JSON [Map].
  factory Contexts.fromJson(Map<String, dynamic> data) {
    final deviceJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryDevice.type);
    final osJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryOperatingSystem.type);
    final appJson = data.getValueOrNull<Map<String, dynamic>>(SentryApp.type);
    final browserJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryBrowser.type);
    final cultureJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryCulture.type);
    final gpuJson = data.getValueOrNull<Map<String, dynamic>>(SentryGpu.type);
    final traceJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryTraceContext.type);
    final runtimeJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryRuntime.type);
    final responseJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryResponse.type);
    final feedbackJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryFeedback.type);
    final flagsJson =
        data.getValueOrNull<Map<String, dynamic>>(SentryFeatureFlags.type);
    final contexts = Contexts(
      device: deviceJson != null
          ? SentryDevice.fromJson(Map<String, dynamic>.from(deviceJson))
          : null,
      operatingSystem: osJson != null
          ? SentryOperatingSystem.fromJson(Map<String, dynamic>.from(osJson))
          : null,
      app: appJson != null
          ? SentryApp.fromJson(Map<String, dynamic>.from(appJson))
          : null,
      browser: browserJson != null
          ? SentryBrowser.fromJson(Map<String, dynamic>.from(browserJson))
          : null,
      culture: cultureJson != null
          ? SentryCulture.fromJson(Map<String, dynamic>.from(cultureJson))
          : null,
      gpu: gpuJson != null
          ? SentryGpu.fromJson(Map<String, dynamic>.from(gpuJson))
          : null,
      trace: traceJson != null
          ? SentryTraceContext.fromJson(Map<String, dynamic>.from(traceJson))
          : null,
      runtimes: runtimeJson != null
          ? [SentryRuntime.fromJson(Map<String, dynamic>.from(runtimeJson))]
          : null,
      response: responseJson != null
          ? SentryResponse.fromJson(Map<String, dynamic>.from(responseJson))
          : null,
      feedback: feedbackJson != null
          ? SentryFeedback.fromJson(Map<String, dynamic>.from(feedbackJson))
          : null,
      flags: flagsJson != null
          ? SentryFeatureFlags.fromJson(Map<String, dynamic>.from(flagsJson))
          : null,
    );

    data.keys
        .where((key) => !defaultFields.contains(key) && data[key] != null)
        .forEach((key) => contexts[key] = data[key]);

    return contexts;
  }

  /// This describes the device that caused the event.
  SentryDevice? get device => this[SentryDevice.type];

  set device(SentryDevice? device) => this[SentryDevice.type] = device;

  /// Describes the operating system on which the event was created.
  ///
  /// In web contexts, this is the operating system of the browse
  /// (normally pulled from the User-Agent string).
  SentryOperatingSystem? get operatingSystem =>
      this[SentryOperatingSystem.type];

  set operatingSystem(SentryOperatingSystem? operatingSystem) =>
      this[SentryOperatingSystem.type] = operatingSystem;

  /// Describes an immutable list of runtimes in more detail
  /// (for instance if you have a Flutter application running
  /// on top of Android).
  List<SentryRuntime> get runtimes =>
      List.unmodifiable(this[SentryRuntime.listType] ?? []);

  set runtimes(List<SentryRuntime> runtimes) =>
      this[SentryRuntime.listType] = List<SentryRuntime>.from(runtimes);

  void addRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].add(runtime);

  void removeRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].remove(runtime);

  /// App context describes the application.
  ///
  /// As opposed to the runtime, this is the actual application that was
  /// running and carries metadata about the current session.
  SentryApp? get app => this[SentryApp.type];

  set app(SentryApp? app) => this[SentryApp.type] = app;

  /// Carries information about the browser or user agent for web-related
  /// errors.
  ///
  /// This can either be the browser this event ocurred in, or the user
  /// agent of a web request that triggered the event.
  SentryBrowser? get browser => this[SentryBrowser.type];

  set browser(SentryBrowser? browser) => this[SentryBrowser.type] = browser;

  /// Culture Context describes certain properties of the culture in which the
  /// software is used.
  SentryCulture? get culture => this[SentryCulture.type];

  set culture(SentryCulture? culture) => this[SentryCulture.type] = culture;

  /// GPU context describes the GPU of the device.
  SentryGpu? get gpu => this[SentryGpu.type];

  set gpu(SentryGpu? gpu) => this[SentryGpu.type] = gpu;

  /// The tracing context of the transaction
  SentryTraceContext? get trace => this[SentryTraceContext.type];

  set trace(SentryTraceContext? trace) => this[SentryTraceContext.type] = trace;

  /// Response context for a HTTP response. Not added automatically.
  SentryResponse? get response => this[SentryResponse.type];

  /// Use [Hint.response] in `beforeSend/beforeSendTransaction` to populate this value.
  set response(SentryResponse? value) => this[SentryResponse.type] = value;

  /// Feedback context for a feedback event.
  SentryFeedback? get feedback => this[SentryFeedback.type];

  set feedback(SentryFeedback? value) => this[SentryFeedback.type] = value;

  /// Feature flags context for a feature flag event.
  SentryFeatureFlags? get flags => this[SentryFeatureFlags.type];

  set flags(SentryFeatureFlags? value) => this[SentryFeatureFlags.type] = value;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    forEach((key, value) {
      if (value == null) return;
      switch (key) {
        case SentryDevice.type:
          final deviceMap = device?.toJson();
          if (deviceMap?.isNotEmpty ?? false) {
            json[SentryDevice.type] = deviceMap;
          }
          break;
        case SentryOperatingSystem.type:
          final osMap = operatingSystem?.toJson();
          if (osMap?.isNotEmpty ?? false) {
            json[SentryOperatingSystem.type] = osMap;
          }
          break;

        case SentryApp.type:
          final appMap = app?.toJson();
          if (appMap?.isNotEmpty ?? false) {
            json[SentryApp.type] = appMap;
          }
          break;

        case SentryBrowser.type:
          final browserMap = browser?.toJson();
          if (browserMap?.isNotEmpty ?? false) {
            json[SentryBrowser.type] = browserMap;
          }
          break;

        case SentryCulture.type:
          final cultureMap = culture?.toJson();
          if (cultureMap?.isNotEmpty ?? false) {
            json[SentryCulture.type] = cultureMap;
          }
          break;

        case SentryGpu.type:
          final gpuMap = gpu?.toJson();
          if (gpuMap?.isNotEmpty ?? false) {
            json[SentryGpu.type] = gpuMap;
          }
          break;

        case SentryResponse.type:
          final responseMap = response?.toJson();
          if (responseMap?.isNotEmpty ?? false) {
            json[SentryResponse.type] = responseMap;
          }
          break;

        case SentryTraceContext.type:
          final traceMap = trace?.toJson();
          if (traceMap?.isNotEmpty ?? false) {
            json[SentryTraceContext.type] = traceMap;
          }
          break;

        case SentryFeedback.type:
          final feedbackMap = feedback?.toJson();
          if (feedbackMap?.isNotEmpty ?? false) {
            json[SentryFeedback.type] = feedbackMap;
          }
          break;

        case SentryRuntime.listType:
          if (runtimes.length == 1) {
            final runtime = runtimes[0];
            final runtimeMap = runtime.toJson();
            if (runtimeMap.isNotEmpty) {
              final key = runtime.key ?? SentryRuntime.type;

              json[key] = runtimeMap;
            }
          } else if (runtimes.length > 1) {
            for (final runtime in runtimes) {
              final runtimeMap = runtime.toJson();
              if (runtimeMap.isNotEmpty) {
                var key = runtime.key ?? runtime.name!.toLowerCase();

                if (json.containsKey(key)) {
                  var k = 0;
                  while (json.containsKey(key)) {
                    key = '$key$k';
                    k++;
                  }
                }
                json[key] = runtimeMap
                  ..addAll(<String, String>{'type': SentryRuntime.type});
              }
            }
          }

          break;

        case SentryFeatureFlags.type:
          final flagsMap = flags?.toJson();
          if (flagsMap?.isNotEmpty ?? false) {
            json[SentryFeatureFlags.type] = flagsMap;
          }
          break;

        default:
          if (value != null) {
            json[key] = value;
          }
      }
    });

    return json;
  }

  @Deprecated('Will be removed in a future version.')
  Contexts clone() {
    final copy = Contexts(
      device: device?.clone(),
      operatingSystem: operatingSystem?.clone(),
      app: app?.clone(),
      browser: browser?.clone(),
      culture: culture?.clone(),
      gpu: gpu?.clone(),
      trace: trace?.clone(),
      response: response?.clone(),
      runtimes: runtimes.map((runtime) => runtime.clone()).toList(),
      feedback: feedback?.clone(),
      flags: flags?.clone(),
    )..addEntries(
        entries.where((element) => !defaultFields.contains(element.key)),
      );

    return copy;
  }

  @Deprecated(
      'Will be removed in a future version. Assign values directly to the instance.')
  Contexts copyWith({
    SentryDevice? device,
    SentryOperatingSystem? operatingSystem,
    List<SentryRuntime>? runtimes,
    SentryApp? app,
    SentryBrowser? browser,
    SentryCulture? culture,
    SentryGpu? gpu,
    SentryTraceContext? trace,
    SentryResponse? response,
    SentryFeedback? feedback,
    SentryFeatureFlags? flags,
  }) =>
      Contexts(
        device: device ?? this.device,
        operatingSystem: operatingSystem ?? this.operatingSystem,
        runtimes: runtimes ??
            List<SentryRuntime>.from(this[SentryRuntime.listType] ?? []),
        app: app ?? this.app,
        browser: browser ?? this.browser,
        gpu: gpu ?? this.gpu,
        culture: culture ?? this.culture,
        trace: trace ?? this.trace,
        response: response ?? this.response,
        feedback: feedback ?? this.feedback,
        flags: flags ?? this.flags,
      )..addEntries(
          entries.where((element) => !defaultFields.contains(element.key)),
        );

  @internal
  static const defaultFields = [
    SentryApp.type,
    SentryDevice.type,
    SentryOperatingSystem.type,
    SentryRuntime.listType,
    SentryRuntime.type,
    SentryGpu.type,
    SentryBrowser.type,
    SentryCulture.type,
    SentryTraceContext.type,
    SentryResponse.type,
    SentryFeedback.type,
    SentryFeatureFlags.type,
  ];
}
