import 'dart:ui';
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => HtmlMultiViewHelper();

class HtmlMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    try {
      return null == PlatformDispatcher.instance.implicitView;
    } on NoSuchMethodError catch (_) {
      return false;
    }
  }
}
