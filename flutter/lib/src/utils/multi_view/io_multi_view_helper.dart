import 'multi_view_helper.dart';

MultiViewHelper multiViewHelper() => IoMultiViewHelper();

class IoMultiViewHelper implements MultiViewHelper {
  @override
  bool isMultiViewEnabled() {
    return false;
  }
}
