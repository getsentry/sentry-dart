import 'package:flutter/widgets.dart';

/// mixins do not allow extension methods.
class BindingUtils {
  /// Flutter >= 2.12 throws if WidgetsBinding.instance isn't initialized.
  // When this method is called, it is guaranteed that a binding was already
  // initialized.
  WidgetsBinding getWidgetsBindingInstance() {
    return _ambiguate(WidgetsBinding.instance)!;
  }

  /// Initializes the Binding.
  void ensureBindingInitialized() {
    WidgetsFlutterBinding.ensureInitialized();
  }
}

WidgetsBinding? _ambiguate(WidgetsBinding? binding) => binding;
