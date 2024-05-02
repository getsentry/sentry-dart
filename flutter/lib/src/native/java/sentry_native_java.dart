import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter_options.dart';
import '../sentry_native_channel.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as java;

@internal
class SentryNativeJava extends SentryNativeChannel {
  SentryNativeJava(super.channel);

  @override
  Future<void> init(SentryFlutterOptions options) async {
    if (options.replay.isEnabled) {
      // Necessary for the generated binding to work as of jnigen v0.6.0
      // This may change in the future.
      Jni.initDLApi();

      java.SentryFlutterReplay.recorder = AndroidReplayRecorder.create(options);
    }
    return super.init(options);
  }
}
