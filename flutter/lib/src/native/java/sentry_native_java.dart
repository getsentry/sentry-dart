import 'package:meta/meta.dart';

import '../sentry_native_channel.dart';

// Note: currently this doesn't do anything. Later, it shall be used with
// generated JNI bindings. See https://github.com/getsentry/sentry-dart/issues/1444
@internal
class SentryNativeJava extends SentryNativeChannel {
  SentryNativeJava(super.options, super.channel);
}
