import 'package:meta/meta.dart';

import 'package.dart';

/// Describes the SDK that is submitting events to Sentry.
///
/// https://develop.sentry.dev/sdk/event-payloads/sdk/
///
/// SDK's maintained by Sentry take the following format:
/// sentry.lang and for specializations: sentry.lang.specialization
///
/// Examples: sentry.dart, sentry.dart.browser, sentry.dart.flutter
///
/// It can also contain the packages bundled and integrations enabled.
///
/// ```
/// "sdk": {
///   "name": "sentry.dart.flutter",
///   "version": "5.0.0",
///   "integrations": [
///     "tracing"
///   ],
///   "packages": [
///     {
///       "name": "git:https://github.com/getsentry/sentry-cocoa.git",
///       "version": "5.1.0"
///     },
///     {
///       "name": "maven:io.sentry.android",
///       "version": "2.2.0"
///     }
///   ]
/// }
/// ```
@immutable
class Sdk {
  /// Creates an [Sdk] object which represents the SDK that created an [Event].
  Sdk({
    @required this.name,
    @required this.version,
    List<String> integrations,
    List<Package> packages,
  })  : assert(name != null || version != null),
        _integrations = integrations ?? [],
        _packages = packages ?? [];

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  final List<String> _integrations;

  /// A list of integrations enabled in the SDK that created the [Event].
  List<String> get integrations => List.unmodifiable(_integrations);

  final List<Package> _packages;

  /// A list of packages that compose this SDK.
  List<Package> get packages => List.unmodifiable(_packages);

  String get identifier => '${name}/${version}';

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['name'] = name;
    json['version'] = version;

    if (packages != null && packages.isNotEmpty) {
      json['packages'] =
          packages.map((p) => p.toJson()).toList(growable: false);
    }

    if (integrations != null && integrations.isNotEmpty) {
      json['integrations'] = integrations;
    }
    return json;
  }

  /// Adds a package
  void addPackage(String name, String version) {
    final package = Package(name, version);
    _packages.add(package);
  }

  // Adds an integration
  void addIntegration(String integration) {
    _integrations.add(integration);
  }
}
