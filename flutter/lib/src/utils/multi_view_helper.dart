import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'platform_dispatcher_wrapper.dart';

@internal
class MultiViewHelper {
  static PlatformDispatcherWrapper wrapper =
      PlatformDispatcherWrapper(WidgetsBinding.instance.platformDispatcher);

  static bool isMultiViewEnabled() {
    return wrapper.implicitView == null;
  }
}
