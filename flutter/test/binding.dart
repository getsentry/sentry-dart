import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryAutomatedTestWidgetsFlutterBinding
    extends AutomatedTestWidgetsFlutterBinding
    with SentryFrameTrackingBindingMixin {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SentryAutomatedTestWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static SentryAutomatedTestWidgetsFlutterBinding? _instance;

  // ignore: prefer_constructors_over_static_methods
  static SentryAutomatedTestWidgetsFlutterBinding ensureInitialized() {
    if (SentryAutomatedTestWidgetsFlutterBinding._instance == null) {
      SentryAutomatedTestWidgetsFlutterBinding();
    }
    return SentryAutomatedTestWidgetsFlutterBinding.instance;
  }
}
