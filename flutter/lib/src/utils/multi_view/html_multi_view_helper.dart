import 'dart:js' as js;
import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => HtmlMultiViewHelper();

class HtmlMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    return "flutter-view" == js.context['__flutterState'][0].toString();
  }
}
