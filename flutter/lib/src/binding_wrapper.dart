// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

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
      SentryWidgetsFlutterBinding.ensureInitialized();
}

WidgetsBinding? _ambiguate(WidgetsBinding? binding) => binding;

class SentryWidgetsFlutterBinding extends WidgetsFlutterBinding
    with SentryWidgetsBindingMixin {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SentryWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static SentryWidgetsFlutterBinding? _instance;

  /// Returns an instance of [SentryWidgetsFlutterBinding].
  /// If no binding has yet been initialized, creates and initializes one.
  ///
  /// If the binding was already initialized with a different implementation,
  /// returns the existing [WidgetsBinding] instance instead.
  static WidgetsBinding ensureInitialized() {
    try {
      // Try to get the existing binding instance
      return WidgetsBinding.instance;
    } catch (_) {
      Sentry.currentHub.options.logger(
          SentryLevel.info,
          'WidgetsFlutterBinding already initialized. '
          'Falling back to existing WidgetsBinding instance.');
      // No binding exists yet, create our custom one
      SentryWidgetsFlutterBinding();
      return WidgetsBinding.instance;
    }
  }
}

@internal
typedef FrameTimingCallback = void Function(
    DateTime startTimestamp, DateTime endTimestamp);

mixin SentryWidgetsBindingMixin on WidgetsBinding {
  DateTime? _startTimestamp;
  FrameTimingCallback? _frameTimingCallback;
  ClockProvider? _clock;

  SentryOptions get _options => Sentry.currentHub.options;

  @internal
  void registerFramesTracking(
      FrameTimingCallback callback, ClockProvider clock) {
    _frameTimingCallback ??= callback;
    _clock ??= clock;
  }

  @visibleForTesting
  bool isFramesTrackingInitialized() {
    return _frameTimingCallback != null && _clock != null;
  }

  @internal
  void removeFramesTracking() {
    _frameTimingCallback = null;
    _clock = null;
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    try {
      _startTimestamp = _clock?.call();
    } catch (_) {
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();

    try {
      final endTimestamp = _clock?.call();
      if (_startTimestamp != null &&
          endTimestamp != null &&
          _startTimestamp!.isBefore(endTimestamp)) {
        _frameTimingCallback?.call(_startTimestamp!, endTimestamp);
      }
    } catch (_) {
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
