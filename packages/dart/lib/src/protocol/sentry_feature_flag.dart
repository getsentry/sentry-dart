import 'package:meta/meta.dart';

import 'access_aware_map.dart';

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
      flag: json['flag'],
      result: json['result'],
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

  @internal
  SentryFeatureFlag clone() {
    return SentryFeatureFlag(
      flag: flag,
      result: result,
      unknown: unknown == null ? null : Map<String, dynamic>.from(unknown!),
    );
  }
}
