// ignore_for_file: invalid_use_of_internal_member

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../sentry_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'frame_tracking/frame_tracker.dart';
import 'native/sentry_native_binding.dart';

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

mixin FrameTrackingBindingMixin on WidgetsBinding {
  FrameTracker get frameTracker => _frameTracker;
  final _frameTracker = FrameTracker();

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    _frameTracker.startFrame();

    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();

    _frameTracker.endFrame();
  }
}

class SentryWidgetsFlutterBinding extends WidgetsFlutterBinding
    with FrameTrackingBindingMixin {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static SentryWidgetsFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static SentryWidgetsFlutterBinding? _instance;

  // ignore: prefer_constructors_over_static_methods
  static WidgetsBinding ensureInitialized() {
    try {
      if (SentryWidgetsFlutterBinding._instance == null) {
        SentryWidgetsFlutterBinding();
      }
      return SentryWidgetsFlutterBinding.instance;
    } catch (e) {
      HubAdapter().options.logger(
          SentryLevel.info,
          'WidgetsFlutterBinding already initialized. '
          'Falling back to default WidgetsBinding instance.');
      return WidgetsBinding.instance;
    }
  }
}
