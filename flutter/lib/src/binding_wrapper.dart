// ignore_for_file: invalid_use_of_internal_member

import '../sentry_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The methods and properties are modelled after the the real binding class.
@experimental
class BindingWrapper {
  final Hub _hub;

  BindingWrapper({Hub? hub}) : _hub = hub ?? HubAdapter();

  /// The current [WidgetsBinding], if one has been created.
  /// Provides access to the features exposed by this mixin.
  /// The binding must be initialized before using this getter;
  /// this is typically done by calling [runApp] or [WidgetsFlutterBinding.ensureInitialized].
  WidgetsBinding? get instance {
    try {
      return _ambiguate(WidgetsBinding.instance);
    } catch (e, s) {
      _hub.options.logger(
        SentryLevel.error,
        'WidgetsBinding.instance was not yet initialized',
        exception: e,
        stackTrace: s,
        logger: 'BindingWrapper',
      );
      if (_hub.options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  /// Returns an instance of the binding that implements [WidgetsBinding].
  /// If no binding has yet been initialized, the [WidgetsFlutterBinding] class
  /// is used to create and initialize one.
  /// You only need to call this method if you need the binding to be
  /// initialized before calling [runApp].
  WidgetsBinding ensureInitialized() =>
      WidgetsFlutterBinding.ensureInitialized();
}

WidgetsBinding? _ambiguate(WidgetsBinding? binding) => binding;
