import 'dart:js' as js;
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => WebMultiViewHelper();

class WebMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    return "flutter-view" == js.context['__flutterState'][0].toString();
  }
}
