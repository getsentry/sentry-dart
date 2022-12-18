import 'package:flutter/widgets.dart';

// The methods and properties are modelled after the the real binding class.
class BindingWrapper {
  /// The current [WidgetsBinding], if one has been created.
  /// Provides access to the features exposed by this mixin.
  /// The binding must be initialized before using this getter;
  /// this is typically done by calling [runApp] or [WidgetsFlutterBinding.ensureInitialized].
  WidgetsBinding? get instance => _ambiguate(WidgetsBinding.instance);

  /// Returns an instance of the binding that implements [WidgetsBinding].
  /// If no binding has yet been initialized, the [WidgetsFlutterBinding] class
  /// is used to create and initialize one.
  /// You only need to call this method if you need the binding to be
  /// initialized before calling [runApp].
  WidgetsBinding ensureInitialized() =>
      WidgetsFlutterBinding.ensureInitialized();
}

WidgetsBinding? _ambiguate(WidgetsBinding? binding) => binding;
