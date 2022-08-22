import 'package:meta/meta.dart';

import 'feature_flag.dart';

@immutable
class FeatureDump {
  final Map<String, FeatureFlag> featureFlags;

  FeatureDump(this.featureFlags);

  factory FeatureDump.fromJson(Map<String, dynamic> json) {
    final featureFlagsJson = json['feature_flags'] as Map?;
    Map<String, FeatureFlag> featureFlags = {};

    if (featureFlagsJson != null) {
      for (final value in featureFlagsJson.entries) {
        final featureFlag = FeatureFlag.fromJson(value.value);
        featureFlags[value.key] = featureFlag;
      }
    }

    return FeatureDump(featureFlags);
  }
}
