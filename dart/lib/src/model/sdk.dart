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
  const Sdk({
    @required this.name,
    @required this.version,
    this.integrations,
    this.packages,
  }) : assert(name != null || version != null);

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  /// A list of integrations enabled in the SDK that created the [Event].
  final List<String> integrations;

  /// A list of packages that compose this SDK.
  final List<Package> packages;

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
}
