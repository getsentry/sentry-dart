// ignore_for_file: invalid_use_of_internal_member

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
          'WidgetsFlutterBinding has not been initialized yet. '
          'Creating $SentryWidgetsFlutterBinding.');
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
  FrameTimingCallback? _onDelayedFrame;
  FrameTimingCallback? get onDelayedFrame => _onDelayedFrame;
  Duration? _expectedFrameDuration;
  Duration? get expectedFrameDuration => _expectedFrameDuration;
  bool _isTrackingActive = false;
  SentryOptions? _options;
  SentryOptions? get options => _options;
  final Stopwatch _stopwatch = Stopwatch();

  @internal
  void initializeFramesTracking(FrameTimingCallback onDelayedFrame,
      SentryOptions options, Duration expectedFrameDuration) {
    _onDelayedFrame ??= onDelayedFrame;
    _options ??= options;
    _expectedFrameDuration ??= expectedFrameDuration;
  }

  void resumeTrackingFrames() {
    _isTrackingActive = true;
  }

  void pauseTrackingFrames() {
    // Stopwatch could continue running if we pause tracking in between a frame
    _stopwatch.stop();
    _stopwatch.reset();
    _isTrackingActive = false;
  }

  @internal
  void removeFramesTracking() {
    _onDelayedFrame = null;
    _expectedFrameDuration = null;
    _options = null;
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    if (_isTrackingActive) {
      try {
        _stopwatch.start();
      } catch (_) {
        if (_options?.automatedTestMode == true) {
          rethrow;
        }
      }
    }

    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();

    if (!_isTrackingActive) {
      return;
    }
    final expectedFrameDuration = _expectedFrameDuration;
    final options = _options;
    try {
      _stopwatch.stop();
      if (options != null &&
          expectedFrameDuration != null &&
          _stopwatch.elapsedMilliseconds >
              expectedFrameDuration.inMilliseconds) {
        final endTimestamp = options.clock();
        final startTimestamp = endTimestamp
            .subtract(Duration(milliseconds: _stopwatch.elapsedMilliseconds));
        _onDelayedFrame?.call(startTimestamp, endTimestamp);
      }
      _stopwatch.reset();
    } catch (_) {
      if (_options?.automatedTestMode == true) {
        rethrow;
      }
    }
  }
}
