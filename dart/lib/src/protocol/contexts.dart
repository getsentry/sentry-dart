import 'dart:collection';

import '../protocol.dart';

/// The context interfaces provide additional context data.
///
/// Typically this is data related to the current user,
/// the current HTTP request.
///
/// See also: https://docs.sentry.io/development/sdk-dev/event-payloads/contexts/.
class Contexts extends MapView<String, dynamic> {
  Contexts({
    Device device,
    OperatingSystem operatingSystem,
    List<SentryRuntime> runtimes,
    App app,
    Browser browser,
    Gpu gpu,
  }) : super({
          Device.type: device,
          OperatingSystem.type: operatingSystem,
          SentryRuntime.listType: runtimes ?? [],
          App.type: app,
          Browser.type: browser,
          Gpu.type: gpu,
        });

  factory Contexts.fromJson(Map<String, dynamic> data) {
    final contexts = Contexts(
      device: data[Device.type] != null
          ? Device.fromJson(Map<String, dynamic>.from(data[Device.type]))
          : null,
      operatingSystem: data[OperatingSystem.type] != null
          ? OperatingSystem.fromJson(
              Map<String, dynamic>.from(data[OperatingSystem.type]))
          : null,
      app: data[App.type] != null
          ? App.fromJson(Map<String, dynamic>.from(data[App.type]))
          : null,
      browser: data[Browser.type] != null
          ? Browser.fromJson(Map<String, dynamic>.from(data[Browser.type]))
          : null,
      gpu: data[Gpu.type] != null
          ? Gpu.fromJson(Map<String, dynamic>.from(data[Gpu.type]))
          : null,
      runtimes: data[SentryRuntime.type] != null
          ? [
              SentryRuntime.fromJson(
                Map<String, dynamic>.from(data[SentryRuntime.type]),
              ),
            ]
          : null,
    );

    data.keys
        .where((key) => !_defaultFields.contains(key) && data[key] != null)
        .forEach((key) => contexts[key] = data[key]);

    return contexts;
  }

  /// This describes the device that caused the event.
  Device get device => this[Device.type];

  set device(Device device) => this[Device.type] = device;

  /// Describes the operating system on which the event was created.
  ///
  /// In web contexts, this is the operating system of the browse
  /// (normally pulled from the User-Agent string).
  OperatingSystem get operatingSystem => this[OperatingSystem.type];

  set operatingSystem(OperatingSystem operatingSystem) =>
      this[OperatingSystem.type] = operatingSystem;

  /// Describes an immutable list of runtimes in more detail
  /// (for instance if you have a Flutter application running
  /// on top of Android).
  List<SentryRuntime> get runtimes =>
      List.unmodifiable(this[SentryRuntime.listType]);

  void addRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].add(runtime);

  void removeRuntime(SentryRuntime runtime) =>
      this[SentryRuntime.listType].remove(runtime);

  /// App context describes the application.
  ///
  /// As opposed to the runtime, this is the actual application that was
  /// running and carries metadata about the current session.
  App get app => this[App.type];

  set app(App app) => this[App.type] = app;

  /// Carries information about the browser or user agent for web-related
  /// errors.
  ///
  /// This can either be the browser this event ocurred in, or the user
  /// agent of a web request that triggered the event.
  Browser get browser => this[Browser.type];

  set browser(Browser browser) => this[Browser.type] = browser;

  /// GPU context describes the GPU of the device.
  Gpu get gpu => this[Gpu.type];

  set gpu(Gpu gpu) => this[Gpu.type] = gpu;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    forEach((key, value) {
      if (value == null) return;
      switch (key) {
        case Device.type:
          Map<String, dynamic> deviceMap;
          if (device != null && (deviceMap = device.toJson()).isNotEmpty) {
            json[Device.type] = deviceMap;
          }
          break;
        case OperatingSystem.type:
          Map<String, dynamic> osMap;
          if (operatingSystem != null &&
              (osMap = operatingSystem.toJson()).isNotEmpty) {
            json[OperatingSystem.type] = osMap;
          }
          break;

        case App.type:
          Map<String, dynamic> appMap;
          if (app != null && (appMap = app.toJson()).isNotEmpty) {
            json[App.type] = appMap;
          }
          break;

        case Browser.type:
          Map<String, dynamic> browserMap;
          if (browser != null && (browserMap = browser.toJson()).isNotEmpty) {
            json[Browser.type] = browserMap;
          }
          break;

        case Gpu.type:
          Map<String, dynamic> gpuMap;
          if (gpu != null && (gpuMap = gpu.toJson()).isNotEmpty) {
            json[Gpu.type] = gpuMap;
          }
          break;

        case SentryRuntime.listType:
          if (runtimes != null) {
            if (runtimes.length == 1) {
              final runtime = runtimes[0];
              Map<String, dynamic> runtimeMap;
              if (runtime != null &&
                  (runtimeMap = runtime.toJson()).isNotEmpty) {
                final key = runtime.key ?? SentryRuntime.type;

                json[key] = runtimeMap;
              }
            } else if (runtimes.length > 1) {
              for (final runtime in runtimes) {
                Map<String, dynamic> runtimeMap;
                if (runtime != null &&
                    (runtimeMap = runtime.toJson()).isNotEmpty) {
                  var key = runtime.key ?? runtime.name.toLowerCase();

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
      gpu: gpu?.clone(),
      runtimes: runtimes.map((runtime) => runtime.clone()).toList(),
    )..addEntries(
        entries.where((element) => !_defaultFields.contains(element.key)),
      );

    return copy;
  }

  static const _defaultFields = [
    App.type,
    Device.type,
    OperatingSystem.type,
    SentryRuntime.listType,
    SentryRuntime.type,
    Gpu.type,
    Browser.type,
  ];
}
