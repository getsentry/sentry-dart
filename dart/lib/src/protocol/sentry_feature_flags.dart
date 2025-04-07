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
        ?.map((e) => SentryFeatureFlag.fromJson(e))
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

  @Deprecated('Assign values directly to the instance.')
  SentryFeatureFlags copyWith({
    List<SentryFeatureFlag>? values,
    Map<String, dynamic>? unknown,
  }) {
    return SentryFeatureFlags(
      values: values ??
          this.values.map((e) => e.copyWith()).toList(growable: false),
      unknown: unknown ?? this.unknown,
    );
  }

  @Deprecated('Will be removed in a future version.')
  SentryFeatureFlags clone() => copyWith();
}
