import 'dart:collection';

import 'package:meta/meta.dart';

import '../protocol.dart';

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
  }) : super({
          SentryDevice.type: device,
          SentryOperatingSystem.type: operatingSystem,
          SentryRuntime.listType: runtimes ?? [],
          SentryApp.type: app,
          SentryBrowser.type: browser,
          SentryGpu.type: gpu,
          SentryCulture.type: culture,
          SentryTraceContext.type: trace,
          SentryResponse.type: response,
        });

  /// Deserializes [Contexts] from JSON [Map].
  factory Contexts.fromJson(Map<String, dynamic> data) {
    final contexts = Contexts(
      device: data[SentryDevice.type] != null
          ? SentryDevice.fromJson(Map.from(data[SentryDevice.type]))
          : null,
      operatingSystem: data[SentryOperatingSystem.type] != null
          ? SentryOperatingSystem.fromJson(
              Map.from(data[SentryOperatingSystem.type]))
          : null,
      app: data[SentryApp.type] != null
          ? SentryApp.fromJson(Map.from(data[SentryApp.type]))
          : null,
      browser: data[SentryBrowser.type] != null
          ? SentryBrowser.fromJson(Map.from(data[SentryBrowser.type]))
          : null,
      culture: data[SentryCulture.type] != null
          ? SentryCulture.fromJson(Map.from(data[SentryCulture.type]))
          : null,
      gpu: data[SentryGpu.type] != null
          ? SentryGpu.fromJson(Map.from(data[SentryGpu.type]))
          : null,
      trace: data[SentryTraceContext.type] != null
          ? SentryTraceContext.fromJson(Map.from(data[SentryTraceContext.type]))
          : null,
      runtimes: data[SentryRuntime.type] != null
          ? [SentryRuntime.fromJson(Map.from(data[SentryRuntime.type]))]
          : null,
      response: data[SentryResponse.type] != null
          ? SentryResponse.fromJson(Map.from(data[SentryResponse.type]))
          : null,
    );

    data.keys
        .where((key) => !_defaultFields.contains(key) && data[key] != null)
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

  /// Response context for a HTTP response.
  SentryResponse? get response => this[SentryResponse.type];

  set response(SentryResponse? value) => this[SentryResponse.type] = value;

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

        default:
          if (value != null) {
            json[key] = value;
          }
      }
    });

    return json;
  }

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
    )..addEntries(
        entries.where((element) => !_defaultFields.contains(element.key)),
      );

    return copy;
  }

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
  }) =>
      Contexts(
        device: device ?? this.device,
        operatingSystem: operatingSystem ?? this.operatingSystem,
        runtimes: runtimes ?? this.runtimes,
        app: app ?? this.app,
        browser: browser ?? this.browser,
        gpu: gpu ?? this.gpu,
        culture: culture ?? this.culture,
        trace: trace ?? this.trace,
        response: response ?? this.response,
      )..addEntries(
          entries.where((element) => !_defaultFields.contains(element.key)),
        );

  static const _defaultFields = [
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
  ];
}
