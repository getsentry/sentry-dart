import 'dart:collection';

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
  }) : super(<String, dynamic>{
          SentryDevice.type: device,
          SentryOperatingSystem.type: operatingSystem,
          SentryRuntime.listType: runtimes ?? [],
          SentryApp.type: app,
          SentryBrowser.type: browser,
          SentryGpu.type: gpu,
          SentryCulture.type: culture,
        });

  /// Deserializes [Contexts] from JSON [Map].
  // ignore: strict_raw_type
  factory Contexts.fromJson(Map data) {
    // This class should be deserializable from Map<String, dynamic> and Map<Object?, Object?>,
    // because it comes from json.decode which is a Map<String, dynamic> and from
    // methodchannels which is a Map<Object?, Object?>.
    // Map<String, dynamic> and Map<Object?, Object?> only have
    // Map<dynamic, dynamic> as common type constraint
    final contexts = Contexts(
      device: data[SentryDevice.type] != null
          ? SentryDevice.fromJson(data[SentryDevice.type] as Map)
          : null,
      operatingSystem: data[SentryOperatingSystem.type] != null
          ? SentryOperatingSystem.fromJson(
              data[SentryOperatingSystem.type] as Map)
          : null,
      app: data[SentryApp.type] != null
          ? SentryApp.fromJson(data[SentryApp.type] as Map)
          : null,
      browser: data[SentryBrowser.type] != null
          ? SentryBrowser.fromJson(data[SentryBrowser.type] as Map)
          : null,
      culture: data[SentryCulture.type] != null
          ? SentryCulture.fromJson(data[SentryCulture.type] as Map)
          : null,
      gpu: data[SentryGpu.type] != null
          ? SentryGpu.fromJson(data[SentryGpu.type] as Map)
          : null,
      runtimes: data[SentryRuntime.type] != null
          ? [SentryRuntime.fromJson(data[SentryRuntime.type] as Map)]
          : null,
    );

    data.keys
        .where(
            (dynamic key) => !_defaultFields.contains(key) && data[key] != null)
        .map((dynamic key) => key as String)
        .forEach((String key) => contexts[key] = data[key]);

    return contexts;
  }

  /// This describes the device that caused the event.
  SentryDevice? get device => this[SentryDevice.type] as SentryDevice?;

  set device(SentryDevice? device) => this[SentryDevice.type] = device;

  /// Describes the operating system on which the event was created.
  ///
  /// In web contexts, this is the operating system of the browse
  /// (normally pulled from the User-Agent string).
  SentryOperatingSystem? get operatingSystem =>
      this[SentryOperatingSystem.type] as SentryOperatingSystem?;

  set operatingSystem(SentryOperatingSystem? operatingSystem) =>
      this[SentryOperatingSystem.type] = operatingSystem;

  /// Describes an immutable list of runtimes in more detail
  /// (for instance if you have a Flutter application running
  /// on top of Android).
  List<SentryRuntime> get runtimes => List.unmodifiable(
        (this[SentryRuntime.listType] as List<dynamic>?)
                ?.cast<SentryRuntime>() ??
            <SentryRuntime>[],
      );

  void addRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].add(runtime);

  void removeRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].remove(runtime);

  /// App context describes the application.
  ///
  /// As opposed to the runtime, this is the actual application that was
  /// running and carries metadata about the current session.
  SentryApp? get app => this[SentryApp.type] as SentryApp?;

  set app(SentryApp? app) => this[SentryApp.type] = app;

  /// Carries information about the browser or user agent for web-related
  /// errors.
  ///
  /// This can either be the browser this event ocurred in, or the user
  /// agent of a web request that triggered the event.
  SentryBrowser? get browser => this[SentryBrowser.type] as SentryBrowser?;

  set browser(SentryBrowser? browser) => this[SentryBrowser.type] = browser;

  /// Culture Context describes certain properties of the culture in which the
  /// software is used.
  SentryCulture? get culture => this[SentryCulture.type] as SentryCulture?;

  set culture(SentryCulture? culture) => this[SentryCulture.type] = culture;

  /// GPU context describes the GPU of the device.
  SentryGpu? get gpu => this[SentryGpu.type] as SentryGpu?;

  set gpu(SentryGpu? gpu) => this[SentryGpu.type] = gpu;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    forEach((key, dynamic value) {
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
  }) =>
      Contexts(
        device: device ?? this.device,
        operatingSystem: operatingSystem ?? this.operatingSystem,
        runtimes: runtimes ?? this.runtimes,
        app: app ?? this.app,
        browser: browser ?? this.browser,
        gpu: gpu ?? this.gpu,
        culture: culture ?? this.culture,
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
  ];
}
