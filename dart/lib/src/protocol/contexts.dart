import 'dart:collection';

import '../protocol.dart';
import 'app.dart';
import 'browser.dart';
import 'device.dart';
import 'gpu.dart';
import 'runtime.dart';

/// The context interfaces provide additional context data.
///
/// Typically this is data related to the current user,
/// the current HTTP request.
///
/// See also: https://docs.sentry.io/development/sdk-dev/event-payloads/contexts/.
class Contexts extends MapView {
  Contexts({
    Device device,
    OperatingSystem operatingSystem,
    // TODO ? list of runtimes or unique as in Java ?
    List<Runtime> runtimes,
    App app,
    Browser browser,
    Gpu gpu,
  }) : super({
          Device.type: device,
          OperatingSystem.type: operatingSystem,
          'runtimes': runtimes ?? [],
          App.type: app,
          Browser.type: browser,
          Gpu.type: gpu,
        });

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

  /// Describes a list of runtimes in more detail
  /// (for instance if you have a Flutter application running
  /// on top of Android).
  List<Runtime> get runtimes => List.unmodifiable(this['runtimes']);

  void addRuntime(Runtime runtime) => this['runtimes'] = runtimes;

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
          if ((deviceMap = device.toJson()).isNotEmpty) {
            json['device'] = deviceMap;
          }
          break;
        case OperatingSystem.type:
          Map<String, dynamic> osMap;
          if ((osMap = operatingSystem.toJson()).isNotEmpty) {
            json[OperatingSystem.type] = osMap;
          }
          break;

        case App.type:
          Map<String, dynamic> appMap;
          if ((appMap = app.toJson()).isNotEmpty) {
            json[App.type] = appMap;
          }
          break;

        case 'browser':
          Map<String, dynamic> browserMap;
          if ((browserMap = browser.toJson()).isNotEmpty) {
            json['browser'] = browserMap;
          }
          break;

        case 'gpu':
          Map<String, dynamic> gpuMap;
          if ((gpuMap = gpu.toJson()).isNotEmpty) {
            json['gpu'] = gpuMap;
          }
          break;

        case 'runtimes':
          if (runtimes != null) {
            if (runtimes.length == 1) {
              final runtime = runtimes[0];
              if (runtime != null) {
                final key = runtime.key ?? 'runtime';
                json[key] = runtime.toJson();
              }
            } else if (runtimes.length > 1) {
              for (final runtime in runtimes) {
                if (runtime != null) {
                  var key = runtime.key ?? runtime.name.toLowerCase();

                  if (json.containsKey(key)) {
                    var k = 0;
                    while (json.containsKey(key)) {
                      key = '$key$k';
                      k++;
                    }
                  }

                  json[key] = runtime.toJson()
                    ..addAll(<String, String>{'type': 'runtime'});
                }
              }
            }
          }

          break;

        default:
          json[key] = value;
      }
    });

    return json;
  }

  Contexts clone() {
    // TODO ? make each class cloneable ?
    final copy = Contexts(
      device: device,
      operatingSystem: operatingSystem,
      app: app,
      browser: browser,
      gpu: gpu,
      runtimes: runtimes,
    )..addEntries(
        entries.where((element) => !_defaultFields.contains(element.key)),
      );

    return copy;
  }

  static const _defaultFields = [
    App.type,
    Device.type,
    OperatingSystem.type,
    'runtimes',
    Runtime.type,
    Gpu.type,
    Browser.type,
  ];
}
