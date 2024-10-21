import 'io_multi_view_helper.dart'
    if (dart.library.html) 'html_multi_view_helper.dart'
    if (dart.library.js_interop) 'web_multi_view_helper.dart';

abstract class MultiViewHelper {
  bool isMultiViewEnabled();
  factory MultiViewHelper() => multiViewHelper();
}
