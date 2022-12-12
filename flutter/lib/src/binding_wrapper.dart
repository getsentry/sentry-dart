import 'package:flutter/widgets.dart';

// The methods and properties are modelled after the the real binding class.
class BindingWrapper {
  /// Flutter >= 2.12 throws if WidgetsBinding.instance isn't initialized.
  // When this method is called, it is guaranteed that a binding was already
  // initialized.
  WidgetsBinding get instance => _ambiguate(WidgetsBinding.instance);

  /// Initializes the Binding.
  void ensureInitialized() => WidgetsFlutterBinding.ensureInitialized();
}

WidgetsBinding _ambiguate(WidgetsBinding? binding) => binding!;
