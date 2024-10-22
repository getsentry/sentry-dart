import 'dart:ui';
import 'package:meta/meta.dart';

@internal
class MultiViewHelper {
  static bool isMultiViewEnabled() {
    final dynamic uncheckedImplicitView = PlatformDispatcher.instance;
    try {
      return null == uncheckedImplicitView.implicitView;
    } on NoSuchMethodError catch (_) {
      return false;
    }
  }
}
