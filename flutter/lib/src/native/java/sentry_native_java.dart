import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../sentry_native_channel.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as java;

@internal
class SentryNativeJava extends SentryNativeChannel {
  SentryNativeJava(super.channel) {
    Jni.initDLApi();
    java.SentryFlutterReplay.recorder = AndroidReplayRecorder.create();
  }
}
