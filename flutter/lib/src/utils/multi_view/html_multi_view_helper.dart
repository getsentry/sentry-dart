import 'dart:ui';
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => HtmlMultiViewHelper();

class HtmlMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    return null == PlatformDispatcher.instance.implicitView;
  }
}
