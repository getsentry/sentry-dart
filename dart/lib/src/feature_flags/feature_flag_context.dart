typedef FeatureFlagContextCallback = void Function(FeatureFlagContext context);

class FeatureFlagContext {
  Map<String, String> tags = {};

  FeatureFlagContext(this.tags);
}
