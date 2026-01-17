import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

class SentryFeatureFlag {
  final String flag;
  final bool result;

  @internal
  final Map<String, dynamic>? unknown;

  SentryFeatureFlag({
    required this.flag,
    required this.result,
    this.unknown,
  });

  factory SentryFeatureFlag.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    return SentryFeatureFlag(
      flag: json.getValueOrNull('flag')!,
      result: json.getValueOrNull('result')!,
      unknown: json.notAccessed(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'flag': flag,
      'result': result,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryFeatureFlag copyWith({
    String? flag,
    bool? result,
    Map<String, dynamic>? unknown,
  }) {
    return SentryFeatureFlag(
      flag: flag ?? this.flag,
      result: result ?? this.result,
      unknown: unknown ?? this.unknown,
    );
  }

  @Deprecated('Will be removed in a future version.')
  SentryFeatureFlag clone() => copyWith();
}
