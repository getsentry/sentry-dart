typedef FeatureFlagContextCallback = void Function(FeatureFlagContext context);

class FeatureFlagContext {
  // String stickyId;
  // String userId;
  // String deviceId;
  Map<String, dynamic> tags = {};

  // FeatureFlagContext(this.stickyId, this.userId, this.deviceId, this.tags);
  FeatureFlagContext(this.tags);
}
