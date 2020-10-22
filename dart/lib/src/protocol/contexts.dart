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
class Contexts {
  const Contexts({
    this.device,
    this.operatingSystem,
    this.runtimes,
    this.app,
    this.browser,
    this.gpu,
  });

  /// This describes the device that caused the event.
  final Device device;

  /// Describes the operating system on which the event was created.
  ///
  /// In web contexts, this is the operating system of the browse
  /// (normally pulled from the User-Agent string).
  final OperatingSystem operatingSystem;

  /// Describes a runtime in more detail.
  ///
  /// Typically this context is used multiple times if multiple runtimes
  /// are involved (for instance if you have a JavaScript application running
  /// on top of JVM).
  final List<Runtime> runtimes;

  /// App context describes the application.
  ///
  /// As opposed to the runtime, this is the actual application that was
  /// running and carries metadata about the current session.
  final App app;

  /// Carries information about the browser or user agent for web-related
  /// errors.
  ///
  /// This can either be the browser this event ocurred in, or the user
  /// agent of a web request that triggered the event.
  final Browser browser;

  /// GPU context describes the GPU of the device.
  final Gpu gpu;

  // TODO: contexts should accept arbitrary values

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    Map<String, dynamic> deviceMap;
    if (device != null && (deviceMap = device.toJson()).isNotEmpty) {
      json['device'] = deviceMap;
    }

    Map<String, dynamic> osMap;
    if (operatingSystem != null &&
        (osMap = operatingSystem.toJson()).isNotEmpty) {
      json['os'] = osMap;
    }

    Map<String, dynamic> appMap;
    if (app != null && (appMap = app.toJson()).isNotEmpty) {
      json['app'] = appMap;
    }

    Map<String, dynamic> browserMap;
    if (browser != null && (browserMap = browser.toJson()).isNotEmpty) {
      json['browser'] = browserMap;
    }

    Map<String, dynamic> gpuMap;
    if (gpu != null && (gpuMap = gpu.toJson()).isNotEmpty) {
      json['gpu'] = gpuMap;
    }

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

    return json;
  }
}
