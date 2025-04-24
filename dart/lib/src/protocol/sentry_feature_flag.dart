import 'package:meta/meta.dart';

import 'access_aware_map.dart';

class SentryFeatureFlag {
  final String name;
  final bool value;

  @internal
  final Map<String, dynamic>? unknown;

  SentryFeatureFlag({
    required this.name,
    required this.value,
    this.unknown,
  });

  factory SentryFeatureFlag.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    return SentryFeatureFlag(
      name: json['name'],
      value: json['value'],
      unknown: json.notAccessed(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'name': name,
      'value': value,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryFeatureFlag copyWith({
    String? name,
    bool? value,
    Map<String, dynamic>? unknown,
  }) {
    return SentryFeatureFlag(
      name: name ?? this.name,
      value: value ?? this.value,
      unknown: unknown ?? this.unknown,
    );
  }

  @Deprecated('Will be removed in a future version.')
  SentryFeatureFlag clone() => copyWith();
}
