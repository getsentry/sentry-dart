import 'package:meta/meta.dart';

import 'sentry_package.dart';
import 'access_aware_map.dart';

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
class SdkVersion {
  /// Creates an [SdkVersion] object which represents the SDK that created an [Event].
  SdkVersion({
    required this.name,
    required this.version,
    List<String>? integrations,
    List<SentryPackage>? packages,
    this.unknown,
  })  :
        // List.from prevents from having immutable lists
        _integrations = List.from(integrations ?? []),
        _packages = List.from(packages ?? []);

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  final List<String> _integrations;

  /// An immutable list of integrations enabled in the SDK that created the [Event].
  List<String> get integrations => List.unmodifiable(_integrations);

  final List<SentryPackage> _packages;

  /// An immutable list of packages that compose this SDK.
  List<SentryPackage> get packages => List.unmodifiable(_packages);

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SdkVersion] from JSON [Map].
  factory SdkVersion.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final packagesJson = json['packages'] as List<dynamic>?;
    final integrationsJson = json['integrations'] as List<dynamic>?;
    return SdkVersion(
      name: json['name'],
      version: json['version'],
      packages: packagesJson
          ?.map((e) => SentryPackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      integrations: integrationsJson?.map((e) => e as String).toList(),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'name': name,
      'version': version,
      if (packages.isNotEmpty)
        'packages': packages.map((p) => p.toJson()).toList(growable: false),
      if (integrations.isNotEmpty) 'integrations': integrations,
    };
  }

  /// Adds a package
  void addPackage(String name, String version) {
    for (final item in _packages) {
      if (item.name == name && item.version == version) {
        return;
      }
    }

    final package = SentryPackage(name, version);
    _packages.add(package);
  }

  // Adds an integration if not already added
  void addIntegration(String integration) {
    if (_integrations.contains(integration)) {
      return;
    }
    _integrations.add(integration);
  }

  SdkVersion copyWith({
    String? name,
    String? version,
    List<String>? integrations,
    List<SentryPackage>? packages,
  }) =>
      SdkVersion(
        name: name ?? this.name,
        version: version ?? this.version,
        integrations: integrations ?? _integrations,
        packages: packages ?? _packages,
        unknown: unknown,
      );
}
