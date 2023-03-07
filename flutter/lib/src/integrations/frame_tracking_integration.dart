import 'dart:async';

import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

class FrameTrackingIntegration extends Integration<SentryFlutterOptions> {
  SentryFlutterOptions? _options;
  DateTime? _lastFrameTimeStamp;

  final _slowFrame = Duration(milliseconds: 16);
  final _frozenFrame = Duration(milliseconds: 700);

  var _totalFrames = 0;
  var _slowFrames = 0;
  var _frozenFrames = 0;

  var _collecting = false;
  var _active = false;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    _options = options;
    _active = true;
    options.sdk.addIntegration('frameTrackingIntegration');
  }

  @override
  FutureOr<void> close() {
    _active = false;
  }

  void beginFramesCollection() {
    if (!_active) {
      return;
    }
    _collecting = true;

    _totalFrames = 0;
    _slowFrames = 0;
    _frozenFrames = 0;
    // ignore: invalid_use_of_internal_member
    _lastFrameTimeStamp = _options?.clock();

    _options?.bindingUtils.instance?.addPostFrameCallback(_onNewFrame);
  }

  Map<String, SentryMeasurement> endFramesCollection() {
    _collecting = false;

    final total = SentryMeasurement.totalFrames(_totalFrames);
    final slow = SentryMeasurement.slowFrames(_slowFrames);
    final frozen = SentryMeasurement.frozenFrames(_frozenFrames);
    return {
      total.name: total,
      slow.name: slow,
      frozen.name: frozen,
    };
  }

  // Helper

  void _onNewFrame(Duration duration) {
    if (!_collecting || !_active) {
      return;
    }
    final options = _options;
    final lastFrameTimeStamp = _lastFrameTimeStamp;
    if (options == null || lastFrameTimeStamp == null) return;

    // ignore: invalid_use_of_internal_member
    final now = options.clock();
    final frameDuration = now.difference(lastFrameTimeStamp);
    if (frameDuration > _frozenFrame) {
      _frozenFrames += 1;
    } else if (frameDuration > _slowFrame) {
      _slowFrames += 1;
    }
    _totalFrames += 1;
    _lastFrameTimeStamp = now;

    options.bindingUtils.instance?.addPostFrameCallback(_onNewFrame);
  }
}
