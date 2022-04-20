import 'package:flutter/widgets.dart';

/// mixins do not allow extension methods.
class BindingUtils {
  /// Flutter >= 2.12 throws if WidgetsBinding.instance isn't initialized.
  static WidgetsBinding? getWidgetsBindingInstance() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {}
    return null;
  }
}
