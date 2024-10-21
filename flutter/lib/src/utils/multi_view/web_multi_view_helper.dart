import 'dart:ui';
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => WebMultiViewHelper();

class WebMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    return null == PlatformDispatcher.instance.implicitView;
  }
}
