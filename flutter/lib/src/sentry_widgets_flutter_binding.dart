import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../sentry_flutter.dart';
import 'frame_tracking/sentry_frame_tracking_binding_mixin.dart';

class SentryWidgetsFlutterBinding extends WidgetsFlutterBinding
    with SentryFrameTrackingBindingMixin {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SentryWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static SentryWidgetsFlutterBinding? _instance;

  // ignore: prefer_constructors_over_static_methods
  static WidgetsBinding ensureInitialized() {
    try {
      if (SentryWidgetsFlutterBinding._instance == null) {
        SentryWidgetsFlutterBinding();
      }
      return SentryWidgetsFlutterBinding.instance;
    } catch (e) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.logger(
          SentryLevel.info,
          'WidgetsFlutterBinding already initialized. '
          'Falling back to default WidgetsBinding instance.');

      return WidgetsBinding.instance;
    }
  }
}
