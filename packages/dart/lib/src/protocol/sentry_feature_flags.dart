import 'package:meta/meta.dart';
import 'sentry_feature_flag.dart';
import 'access_aware_map.dart';

class SentryFeatureFlags {
  static const type = 'flags';

  List<SentryFeatureFlag> values;

  @internal
  Map<String, dynamic>? unknown;

  SentryFeatureFlags({
    required this.values,
    this.unknown,
  });

  factory SentryFeatureFlags.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    final valuesValues = json['values'] as List<dynamic>?;
    final values = valuesValues
        ?.map((e) => SentryFeatureFlag.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    return SentryFeatureFlags(
      values: values ?? [],
      unknown: json.notAccessed(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'values': values.map((e) => e.toJson()).toList(growable: false),
    };
  }

  @internal
  SentryFeatureFlags clone() {
    final unknown = this.unknown;
    return SentryFeatureFlags(
      values: values.map((flag) => flag.clone()).toList(growable: false),
      unknown: unknown == null ? null : Map<String, dynamic>.from(unknown),
    );
  }
}
