// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:usage/uuid/uuid.dart';

import 'client_stub.dart'
    if (dart.library.html) 'browser.dart'
    if (dart.library.io) 'io.dart';

import 'stack_trace.dart';
import 'utils.dart';
import 'version.dart';

/// Used to provide timestamp for logging.
typedef ClockProvider = DateTime Function();

/// Logs crash reports and events to the Sentry.io service.
abstract class SentryClient {
  /// Creates a new platform appropriate client.
  ///
  /// Creates an `SentryIOClient` if `dart:io` is available and a `SentryBrowserClient` if
  /// `dart:html` is available, otherwise it will throw an unsupported error.
  factory SentryClient({
    @required String dsn,
    Event environmentAttributes,
    bool compressPayload,
    Client httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
  }) =>
      createSentryClient(
        dsn: dsn,
        environmentAttributes: environmentAttributes,
        httpClient: httpClient,
        clock: clock,
        uuidGenerator: uuidGenerator,
        compressPayload: compressPayload,
      );

  /// Sentry.io client identifier for _this_ client.
  static const String sentryClient = '$sdkName/$sdkVersion';

  @protected
  final Client httpClient;

  ClockProvider _clock;
  final UuidGenerator _uuidGenerator;

  /// Contains [Event] attributes that are automatically mixed into all events
  /// captured through this client.
  ///
  /// This event is designed to contain static values that do not change from
  /// event to event, such as local operating system version, the version of
  /// Dart/Flutter SDK, etc. These attributes have lower precedence than those
  /// supplied in the even passed to [capture].
  final Event environmentAttributes;

  final Dsn _dsn;

  /// The DSN URI.
  @visibleForTesting
  Uri get dsnUri => _dsn.uri;

  /// The Sentry.io public key for the project.
  @visibleForTesting
  String get publicKey => _dsn.publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  String get secretKey => _dsn.secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  String get projectId => _dsn.projectId;

  /// Information about the current user.
  ///
  /// This information is sent with every logged event. If the value
  /// of this field is updated, all subsequent events will carry the
  /// new information.
  ///
  /// [Event.userContext] overrides the [User] context set here.
  ///
  /// See also:
  /// * https://docs.sentry.io/learn/context/#capturing-the-user
  User userContext;

  /// Use for browser stacktrace
  final String origin;

  /// Used by sentry to differentiate browser from io environment
  final String _platform;

  SentryClient.base({
    this.httpClient,
    dynamic clock,
    UuidGenerator uuidGenerator,
    String dsn,
    this.environmentAttributes,
    String platform,
    this.origin,
  })  : _dsn = Dsn.parse(dsn),
        _uuidGenerator = uuidGenerator ?? generateUuidV4WithoutDashes,
        _platform = platform ?? sdkPlatform {
    if (clock == null) {
      _clock = getUtcDateTime;
    } else {
      _clock = clock is ClockProvider ? clock : clock.get;
    }
  }

  @visibleForTesting
  String get postUri {
    var port = dsnUri.hasPort &&
            ((dsnUri.scheme == 'http' && dsnUri.port != 80) ||
                (dsnUri.scheme == 'https' && dsnUri.port != 443))
        ? ':${dsnUri.port}'
        : '';
    var pathLength = dsnUri.pathSegments.length;
    String apiPath;
    if (pathLength > 1) {
      // some paths would present before the projectID in the dsnUri
      apiPath =
          (dsnUri.pathSegments.sublist(0, pathLength - 1) + ['api']).join('/');
    } else {
      apiPath = 'api';
    }
    return '${dsnUri.scheme}://${dsnUri.host}${port}/$apiPath/$projectId/store/';
  }

  /// Reports an [event] to Sentry.io.
  Future<SentryResponse> capture({
    @required Event event,
    StackFrameFilter stackFrameFilter,
  }) async {
    final now = _clock();
    var authHeader = 'Sentry sentry_version=6, sentry_client=$sentryClient, '
        'sentry_timestamp=${now.millisecondsSinceEpoch}, sentry_key=$publicKey';
    if (secretKey != null) {
      authHeader += ', sentry_secret=$secretKey';
    }

    final headers = buildHeaders(authHeader);

    final data = <String, dynamic>{
      'project': projectId,
      'event_id': _uuidGenerator(),
      'timestamp': formatDateAsIso8601WithSecondPrecision(now)
    };

    if (environmentAttributes != null) {
      mergeAttributes(environmentAttributes.toJson(), into: data);
    }

    // Merge the user context.
    if (userContext != null) {
      mergeAttributes({'user': userContext.toJson()}, into: data);
    }

    mergeAttributes(
      event.toJson(
        stackFrameFilter: stackFrameFilter,
        origin: origin,
      ),
      into: data,
    );
    mergeAttributes({'platform': _platform}, into: data);

    final body = bodyEncoder(data, headers);

    final response = await httpClient.post(
      postUri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      var errorMessage = 'Sentry.io responded with HTTP ${response.statusCode}';
      if (response.headers['x-sentry-error'] != null) {
        errorMessage += ': ${response.headers['x-sentry-error']}';
      }
      return SentryResponse.failure(errorMessage);
    }

    final String eventId = json.decode(response.body)['id'];
    return SentryResponse.success(eventId: eventId);
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  Future<SentryResponse> captureException({
    @required dynamic exception,
    dynamic stackTrace,
  }) {
    final event = Event(
      exception: exception,
      stackTrace: stackTrace,
    );
    return capture(event: event);
  }

  Future<Null> close() async {
    httpClient.close();
  }

  @override
  String toString() => '$SentryClient("$postUri")';

  @protected
  List<int> bodyEncoder(Map<String, dynamic> data, Map<String, String> headers);

  @protected
  @mustCallSuper
  Map<String, String> buildHeaders(String authHeader) {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (authHeader != null) {
      headers['X-Sentry-Auth'] = authHeader;
    }

    return headers;
  }
}

/// A response from Sentry.io.
///
/// If [isSuccessful] the [eventId] field will contain the ID assigned to the
/// captured event by the Sentry.io backend. Otherwise, the [error] field will
/// contain the description of the error.
@immutable
class SentryResponse {
  const SentryResponse.success({@required this.eventId})
      : isSuccessful = true,
        error = null;

  const SentryResponse.failure(this.error)
      : isSuccessful = false,
        eventId = null;

  /// Whether event was submitted successfully.
  final bool isSuccessful;

  /// The ID Sentry.io assigned to the submitted event for future reference.
  final String eventId;

  /// Error message, if the response is not successful.
  final String error;
}

typedef UuidGenerator = String Function();

String generateUuidV4WithoutDashes() => Uuid().generateV4().replaceAll('-', '');

/// Severity of the logged [Event].
@immutable
class SeverityLevel {
  static const fatal = SeverityLevel._('fatal');
  static const error = SeverityLevel._('error');
  static const warning = SeverityLevel._('warning');
  static const info = SeverityLevel._('info');
  static const debug = SeverityLevel._('debug');

  const SeverityLevel._(this.name);

  /// API name of the level as it is encoded in the JSON protocol.
  final String name;
}

/// Sentry does not take a timezone and instead expects the date-time to be
/// submitted in UTC timezone.
DateTime getUtcDateTime() => DateTime.now().toUtc();

/// An event to be reported to Sentry.io.
@immutable
class Event {
  /// Refers to the default fingerprinting algorithm.
  ///
  /// You do not need to specify this value unless you supplement the default
  /// fingerprint with custom fingerprints.
  static const String defaultFingerprint = '{{ default }}';

  /// Creates an event.
  const Event({
    this.loggerName,
    this.serverName,
    this.release,
    this.environment,
    this.message,
    this.transaction,
    this.exception,
    this.stackTrace,
    this.level,
    this.culprit,
    this.tags,
    this.extra,
    this.fingerprint,
    this.userContext,
    this.contexts,
    this.breadcrumbs,
  });

  /// The logger that logged the event.
  final String loggerName;

  /// Identifies the server that logged this event.
  final String serverName;

  /// The version of the application that logged the event.
  final String release;

  /// The environment that logged the event, e.g. "production", "staging".
  final String environment;

  /// Event message.
  ///
  /// Generally an event either contains a [message] or an [exception].
  final String message;

  /// An object that was thrown.
  ///
  /// It's `runtimeType` and `toString()` are logged. If this behavior is
  /// undesirable, consider using a custom formatted [message] instead.
  final dynamic exception;

  /// The stack trace corresponding to the thrown [exception].
  ///
  /// Can be `null`, a [String], or a [StackTrace].
  final dynamic stackTrace;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  final String transaction;

  /// How important this event is.
  final SeverityLevel level;

  /// What caused this event to be logged.
  final String culprit;

  /// Name/value pairs that events can be searched by.
  final Map<String, String> tags;

  /// Arbitrary name/value pairs attached to the event.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic> extra;

  /// List of breadcrumbs for this event.
  ///
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  final List<Breadcrumb> breadcrumbs;

  /// Information about the current user.
  ///
  /// The value in this field overrides the user context
  /// set in [SentryClient.userContext] for this logged event.
  final User userContext;

  /// The context interfaces provide additional context data.
  /// Typically this is data related to the current user,
  /// the current HTTP request.
  final Contexts contexts;

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// If not specified a default deduplication fingerprint is used. The default
  /// fingerprint may be supplemented by additional fingerprints by specifying
  /// multiple values. The default fingerprint can be specified by adding
  /// [defaultFingerprint] to the list in addition to your custom values.
  ///
  /// Examples:
  ///
  ///     // A completely custom fingerprint:
  ///     var custom = ['foo', 'bar', 'baz'];
  ///     // A fingerprint that supplements the default one with value 'foo':
  ///     var supplemented = [Event.defaultFingerprint, 'foo'];
  final List<String> fingerprint;

  Event copyWith({
    String loggerName,
    String serverName,
    String release,
    String environment,
    String message,
    String transaction,
    dynamic exception,
    dynamic stackTrace,
    SeverityLevel level,
    String culprit,
    Map<String, String> tags,
    Map<String, dynamic> extra,
    List<String> fingerprint,
    User userContext,
    List<Breadcrumb> breadcrumbs,
  }) =>
      Event(
        loggerName: loggerName ?? this.loggerName,
        serverName: serverName ?? this.serverName,
        release: release ?? this.release,
        environment: environment ?? this.environment,
        message: message ?? this.message,
        transaction: transaction ?? this.transaction,
        exception: exception ?? this.exception,
        stackTrace: stackTrace ?? this.stackTrace,
        level: level ?? this.level,
        culprit: culprit ?? this.culprit,
        tags: tags ?? this.tags,
        extra: extra ?? this.extra,
        fingerprint: fingerprint ?? this.fingerprint,
        userContext: userContext ?? this.userContext,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      );

  /// Serializes this event to JSON.
  Map<String, dynamic> toJson(
      {StackFrameFilter stackFrameFilter, String origin}) {
    final json = <String, dynamic>{
      'platform': sdkPlatform,
      'sdk': {
        'version': sdkVersion,
        'name': sdkName,
      },
    };

    if (loggerName != null) {
      json['logger'] = loggerName;
    }

    if (serverName != null) {
      json['server_name'] = serverName;
    }

    if (release != null) {
      json['release'] = release;
    }

    if (environment != null) {
      json['environment'] = environment;
    }

    if (message != null) {
      json['message'] = message;
    }

    if (transaction != null) {
      json['transaction'] = transaction;
    }

    if (exception != null) {
      json['exception'] = [
        <String, dynamic>{
          'type': '${exception.runtimeType}',
          'value': '$exception',
        }
      ];
    }

    if (stackTrace != null) {
      json['stacktrace'] = <String, dynamic>{
        'frames': encodeStackTrace(
          stackTrace,
          stackFrameFilter: stackFrameFilter,
          origin: origin,
        ),
      };
    }

    if (level != null) {
      json['level'] = level.name;
    }

    if (culprit != null) {
      json['culprit'] = culprit;
    }

    if (tags != null && tags.isNotEmpty) {
      json['tags'] = tags;
    }

    if (extra != null && extra.isNotEmpty) {
      json['extra'] = extra;
    }

    Map<String, dynamic> contextsMap;
    if (contexts != null && (contextsMap = contexts.toJson()).isNotEmpty) {
      json['contexts'] = contextsMap;
    }

    Map<String, dynamic> userContextMap;
    if (userContext != null &&
        (userContextMap = userContext.toJson()).isNotEmpty) {
      json['user'] = userContextMap;
    }

    if (fingerprint != null && fingerprint.isNotEmpty) {
      json['fingerprint'] = fingerprint;
    }

    if (breadcrumbs != null && breadcrumbs.isNotEmpty) {
      json['breadcrumbs'] = <String, List<Map<String, dynamic>>>{
        'values': breadcrumbs.map((b) => b.toJson()).toList(growable: false)
      };
    }

    return json;
  }
}

/// The context interfaces provide additional context data.
///
/// Typically this is data related to the current user,
/// the current HTTP request.
///
/// See also: https://docs.sentry.io/development/sdk-dev/event-payloads/contexts/.
class Contexts {
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

  const Contexts({
    this.device,
    this.operatingSystem,
    this.runtimes,
    this.app,
    this.browser,
  });

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

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

            json[key] = runtime.toJson()..addAll({'type': 'runtime'});
          }
        }
      }
    }

    return json;
  }
}

/// This describes the device that caused the event.
class Device {
  /// The name of the device. This is typically a hostname.
  final String name;

  /// The family of the device.
  ///
  /// This is normally the common part of model names across generations.
  /// For instance `iPhone` would be a reasonable family,
  /// so would be `Samsung Galaxy`.
  final String family;

  /// The model name. This for instance can be `Samsung Galaxy S3`.
  final String model;

  /// An internal hardware revision to identify the device exactly.
  final String modelId;

  /// The CPU architecture.
  final String arch;

  /// If the device has a battery, this can be an floating point value
  /// defining the battery level (in the range 0-100).
  final double batteryLevel;

  /// Defines the orientation of a device.
  final Orientation orientation;

  /// The manufacturer of the device.
  final String manufacturer;

  /// The brand of the device.
  final String brand;

  /// The screen resolution. (e.g.: `800x600`, `3040x1444`).
  final String screenResolution;

  /// A floating point denoting the screen density.
  final double screenDensity;

  /// A decimal value reflecting the DPI (dots-per-inch) density.
  final int screenDpi;

  /// Whether the device was online or not.
  final bool online;

  /// Whether the device was charging or not.
  final bool charging;

  /// Whether the device was low on memory.
  final bool lowMemory;

  /// A flag indicating whether this device is a simulator or an actual device.
  final bool simulator;

  /// Total system memory available in bytes.
  final int memorySize;

  /// Free system memory in bytes.
  final int freeMemory;

  /// Memory usable for the app in bytes.
  final int usableMemory;

  /// Total device storage in bytes.
  final int storageSize;

  /// Free device storage in bytes.
  final int freeStorage;

  /// Total size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  final int externalStorageSize;

  /// Free size of an attached external storage in bytes
  /// (e.g.: android SDK card).
  final int externalFreeStorage;

  /// When the system was booted
  final DateTime bootTime;

  /// The timezone of the device, e.g.: `Europe/Vienna`.
  final String timezone;

  const Device({
    this.name,
    this.family,
    this.model,
    this.modelId,
    this.arch,
    this.batteryLevel,
    this.orientation,
    this.manufacturer,
    this.brand,
    this.screenResolution,
    this.screenDensity,
    this.screenDpi,
    this.online,
    this.charging,
    this.lowMemory,
    this.simulator,
    this.memorySize,
    this.freeMemory,
    this.usableMemory,
    this.storageSize,
    this.freeStorage,
    this.externalStorageSize,
    this.externalFreeStorage,
    this.bootTime,
    this.timezone,
  }) : assert(
            batteryLevel == null || (batteryLevel >= 0 && batteryLevel <= 100));

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

    String orientation;

    switch (this.orientation) {
      case Orientation.portrait:
        orientation = 'portait';
        break;
      case Orientation.landscape:
        orientation = 'landscape';
        break;
    }

    if (name != null) json['name'] = name;

    if (family != null) json['family'] = family;

    if (model != null) json['model'] = model;

    if (modelId != null) json['model_id'] = modelId;

    if (arch != null) json['arch'] = arch;

    if (batteryLevel != null) json['battery_level'] = batteryLevel;

    if (orientation != null) json['orientation'] = orientation;

    if (manufacturer != null) json['manufacturer'] = manufacturer;

    if (brand != null) json['brand'] = brand;

    if (screenResolution != null) json['screen_resolution'] = screenResolution;

    if (screenDensity != null) json['screen_density'] = screenDensity;

    if (screenDpi != null) json['screen_dpi'] = screenDpi;

    if (online != null) json['online'] = online;

    if (charging != null) json['charging'] = charging;

    if (lowMemory != null) json['low_memory'] = lowMemory;

    if (simulator != null) json['simulator'] = simulator;

    if (memorySize != null) json['memory_size'] = memorySize;

    if (freeMemory != null) json['free_memory'] = freeMemory;

    if (usableMemory != null) json['usable_memory'] = usableMemory;

    if (storageSize != null) json['storage_size'] = storageSize;

    if (freeStorage != null) json['free_storage'] = freeStorage;

    if (externalStorageSize != null) {
      json['external_storage_size'] = externalStorageSize;
    }

    if (externalFreeStorage != null) {
      json['external_free_storage'] = externalFreeStorage;
    }

    if (bootTime != null) json['boot_time'] = bootTime.toIso8601String();

    if (timezone != null) json['timezone'] = timezone;

    return json;
  }
}

enum Orientation { portrait, landscape }

/// Describes the operating system on which the event was created.
///
/// In web contexts, this is the operating system of the browse
/// (normally pulled from the User-Agent string).
class OperatingSystem {
  /// The name of the operating system.
  final String name;

  /// The version of the operating system.
  final String version;

  /// The internal build revision of the operating system.
  final String build;

  /// An independent kernel version string.
  ///
  /// This is typically the entire output of the `uname` syscall.
  final String kernelVersion;

  /// A flag indicating whether the OS has been jailbroken or rooted.
  final bool rooted;

  /// An unprocessed description string obtained by the operating system.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name and
  /// version from this string, if they are not explicitly given.
  final String rawDescription;

  const OperatingSystem({
    this.name,
    this.version,
    this.build,
    this.kernelVersion,
    this.rooted,
    this.rawDescription,
  });

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

    if (name != null) json['name'] = name;

    if (version != null) json['version'] = version;

    if (build != null) json['build'] = build;

    if (kernelVersion != null) json['kernel_version'] = kernelVersion;

    if (rooted != null) json['rooted'] = rooted;

    if (rawDescription != null) json['raw_description'] = rawDescription;

    return json;
  }
}

/// Describes a runtime in more detail.
///
/// Typically this context is used multiple times if multiple runtimes
/// are involved (for instance if you have a JavaScript application running
/// on top of JVM).
class Runtime {
  /// Key used in the JSON and which will be displayed
  /// in the Sentry UI. Defaults to lower case version of [name].
  ///
  /// Unused if only one [Runtime] is provided in [Contexts].
  final String key;

  /// The name of the runtime.
  final String name;

  /// The version identifier of the runtime.
  final String version;

  /// An unprocessed description string obtained by the runtime.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name
  /// and version from this string, if they are not explicitly given.
  final String rawDescription;

  const Runtime({this.key, this.name, this.version, this.rawDescription})
      // ignore: prefer_is_empty
      : assert(key == null || key.length >= 1);

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

    if (name != null) json['name'] = name;

    if (version != null) json['version'] = version;

    if (rawDescription != null) json['raw_description'] = rawDescription;

    return json;
  }
}

/// App context describes the application.
///
/// As opposed to the runtime, this is the actual application that was
/// running and carries metadata about the current session.
class App {
  /// Human readable application name, as it appears on the platform.
  final String name;

  /// Human readable application version, as it appears on the platform.
  final String version;

  /// Version-independent application identifier, often a dotted bundle ID.
  final String identifier;

  /// Internal build identifier, as it appears on the platform.
  final String build;

  /// String identifying the kind of build, e.g. `testflight`.
  final String buildType;

  /// When the application was started by the user.
  final DateTime startTime;

  /// Application specific device identifier.
  final String deviceAppHash;

  const App({
    this.name,
    this.version,
    this.identifier,
    this.build,
    this.buildType,
    this.startTime,
    this.deviceAppHash,
  });

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

    if (name != null) json['app_name'] = name;

    if (version != null) json['app_version'] = version;

    if (identifier != null) json['app_identifier'] = identifier;

    if (build != null) json['app_build'] = build;

    if (buildType != null) json['build_type'] = buildType;

    if (startTime != null) json['app_start_time'] = startTime.toIso8601String();

    if (deviceAppHash != null) json['device_app_hash'] = deviceAppHash;

    return json;
  }
}

/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
class Browser {
  /// Human readable application name, as it appears on the platform.
  final String name;

  /// Human readable application version, as it appears on the platform.
  final String version;

  const Browser({this.name, this.version});

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> json = {};

    if (name != null) json['name'] = name;

    if (version != null) json['version'] = version;

    return json;
  }
}

/// Describes the current user associated with the application, such as the
/// currently signed in user.
///
/// The user can be specified globally in the [SentryClient.userContext] field,
/// or per event in the [Event.userContext] field.
///
/// You should provide at least either an [id] (a unique identifier for an
/// authenticated user) or [ipAddress] (their IP address).
///
/// Conforms to the User Interface contract for Sentry
/// https://docs.sentry.io/clientdev/interfaces/user/.
///
/// The outgoing JSON representation is:
///
/// ```
/// "user": {
///   "id": "unique_id",
///   "username": "my_user",
///   "email": "foo@example.com",
///   "ip_address": "127.0.0.1",
///   "subscription": "basic"
/// }
/// ```
class User {
  /// A unique identifier of the user.
  final String id;

  /// The username of the user.
  final String username;

  /// The email address of the user.
  final String email;

  /// The IP of the user.
  final String ipAddress;

  /// Any other user context information that may be helpful.
  ///
  /// These keys are stored as extra information but not specifically processed
  /// by Sentry.
  final Map<String, dynamic> extras;

  /// At a minimum you must set an [id] or an [ipAddress].
  const User({this.id, this.username, this.email, this.ipAddress, this.extras})
      : assert(id != null || ipAddress != null);

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'ip_address': ipAddress,
      'extras': extras,
    };
  }
}

/// Structed data to describe more information pior to the event [captured][SentryClient.capture].
///
/// The outgoing JSON representation is:
///
/// ```
/// {
///   "timestamp": 1000
///   "message": "message",
///   "category": "category",
///   "data": {"key": "value"},
///   "level": "info",
///   "type": "default"
/// }
/// ```
/// See also:
/// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/
class Breadcrumb {
  /// Describes the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final String message;

  /// A dot-separated string describing the source of the breadcrumb, e.g. "ui.click".
  ///
  /// This field is optional and may be set to null.
  final String category;

  /// Data associated with the breadcrumb.
  ///
  /// The contents depend on the [type] of breadcrumb.
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/#breadcrumb-types
  final Map<String, String> data;

  /// Severity of the breadcrumb.
  ///
  /// This field is optional and may be set to null.
  final SeverityLevel level;

  /// Describes what type of breadcrumb this is.
  ///
  /// Possible values: "default", "http", "navigation".
  ///
  /// This field is optional and may be set to null.
  ///
  /// See also:
  ///
  /// * https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/#breadcrumb-types
  final String type;

  /// The time the breadcrumb was recorded.
  ///
  /// This field is required, it must not be null.
  ///
  /// The value is submitted to Sentry with second precision.
  final DateTime timestamp;

  /// Creates a breadcrumb that can be attached to an [Event].
  const Breadcrumb(
    this.message,
    this.timestamp, {
    this.category,
    this.data,
    this.level = SeverityLevel.info,
    this.type,
  }) : assert(timestamp != null);

  /// Converts this breadcrumb to a map that can be serialized to JSON according
  /// to the Sentry protocol.
  Map<String, dynamic> toJson() {
    var json = <String, dynamic>{
      'timestamp': formatDateAsIso8601WithSecondPrecision(timestamp),
    };
    if (message != null) {
      json['message'] = message;
    }
    if (category != null) {
      json['category'] = category;
    }
    if (data != null && data.isNotEmpty) {
      json['data'] = Map.of(data);
    }
    if (level != null) {
      json['level'] = level.name;
    }
    if (type != null) {
      json['type'] = type;
    }
    return json;
  }
}

class Dsn {
  /// The Sentry.io public key for the project.
  @visibleForTesting
  final String publicKey;

  /// The Sentry.io secret key for the project.
  @visibleForTesting
  final String secretKey;

  /// The ID issued by Sentry.io to your project.
  ///
  /// Attached to the event payload.
  final String projectId;

  /// The DSN URI.
  final Uri uri;

  Dsn({
    @required this.publicKey,
    @required this.projectId,
    this.uri,
    this.secretKey,
  });

  static Dsn parse(String dsn) {
    final uri = Uri.parse(dsn);
    final userInfo = uri.userInfo.split(':');

    assert(() {
      if (uri.pathSegments.isEmpty) {
        throw ArgumentError(
          'Project ID not found in the URI path of the DSN URI: $dsn',
        );
      }

      return true;
    }());

    return Dsn(
      publicKey: userInfo[0],
      secretKey: userInfo.length >= 2 ? userInfo[1] : null,
      projectId: uri.pathSegments.last,
      uri: uri,
    );
  }
}
