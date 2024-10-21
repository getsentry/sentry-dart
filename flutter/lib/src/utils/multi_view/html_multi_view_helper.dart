import 'dart:ui';
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => HtmlMultiViewHelper();

class HtmlMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    final dynamic uncheckedImplicitView = PlatformDispatcher.instance;
    try {
      return null == uncheckedImplicitView.implicitView;
    } on NoSuchMethodError catch (_) {
      return false;
    }
  }
}
