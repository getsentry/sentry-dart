# Keep classes and their nested classes accessed via JNI from the `package:jni`-generated
# bindings in lib/src/native/java/binding.dart. This list mirrors the `classes:` entries in
# ffi-jni.yaml -- keep the two in sync when that binding surface changes.
-keep class io.sentry.android.core.SentryAndroid { *; }
-keep class io.sentry.android.core.SentryAndroid$* { *; }
-keep class io.sentry.android.core.SentryAndroidOptions { *; }
-keep class io.sentry.android.core.SentryAndroidOptions$* { *; }
-keep class io.sentry.android.core.InternalSentrySdk { *; }
-keep class io.sentry.android.core.InternalSentrySdk$* { *; }
-keep class io.sentry.android.core.BuildConfig { *; }
-keep class io.sentry.android.core.BuildConfig$* { *; }
-keep class io.sentry.android.replay.ReplayIntegration { *; }
-keep class io.sentry.android.replay.ReplayIntegration$* { *; }
-keep class io.sentry.android.replay.ScreenshotRecorderConfig { *; }
-keep class io.sentry.android.replay.ScreenshotRecorderConfig$* { *; }
-keep class io.sentry.flutter.SentryFlutterPlugin { *; }
-keep class io.sentry.flutter.SentryFlutterPlugin$* { *; }
-keep class io.sentry.flutter.ReplayRecorderCallbacks { *; }
-keep class io.sentry.flutter.ReplayRecorderCallbacks$* { *; }
-keep class io.sentry.Sentry { *; }
-keep class io.sentry.Sentry$* { *; }
-keep class io.sentry.SentryOptions { *; }
-keep class io.sentry.SentryOptions$* { *; }
-keep class io.sentry.SentryReplayOptions { *; }
-keep class io.sentry.SentryReplayOptions$* { *; }
-keep class io.sentry.SentryReplayEvent { *; }
-keep class io.sentry.SentryReplayEvent$* { *; }
-keep class io.sentry.SentryEvent { *; }
-keep class io.sentry.SentryEvent$* { *; }
-keep class io.sentry.SentryBaseEvent { *; }
-keep class io.sentry.SentryBaseEvent$* { *; }
-keep class io.sentry.SentryLevel { *; }
-keep class io.sentry.SentryLevel$* { *; }
-keep class io.sentry.Hint { *; }
-keep class io.sentry.Hint$* { *; }
-keep class io.sentry.ReplayRecording { *; }
-keep class io.sentry.ReplayRecording$* { *; }
-keep class io.sentry.Breadcrumb { *; }
-keep class io.sentry.Breadcrumb$* { *; }
-keep class io.sentry.ScopesAdapter { *; }
-keep class io.sentry.ScopesAdapter$* { *; }
-keep class io.sentry.Scope { *; }
-keep class io.sentry.Scope$* { *; }
-keep class io.sentry.ScopeCallback { *; }
-keep class io.sentry.ScopeCallback$* { *; }
-keep class io.sentry.protocol.User { *; }
-keep class io.sentry.protocol.User$* { *; }
-keep class io.sentry.protocol.SentryId { *; }
-keep class io.sentry.protocol.SentryId$* { *; }
-keep class io.sentry.protocol.SdkVersion { *; }
-keep class io.sentry.protocol.SdkVersion$* { *; }
-keep class io.sentry.protocol.SentryPackage { *; }
-keep class io.sentry.protocol.SentryPackage$* { *; }
-keep class io.sentry.rrweb.RRWebOptionsEvent { *; }
-keep class io.sentry.rrweb.RRWebOptionsEvent$* { *; }
-keep class io.sentry.rrweb.RRWebEvent { *; }
-keep class io.sentry.rrweb.RRWebEvent$* { *; }
-keep class io.sentry.SentryTraceHeader { *; }
-keep class io.sentry.SentryTraceHeader$* { *; }

# NDK-layer native method signatures and other JNI/reflection needs of the underlying Java SDK
# are already covered by the consumer proguard rules bundled in the sentry-android-core and
# sentry-android-ndk AARs -- no need to duplicate them here.

-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.Bitmap$Config { *; }
-keep class java.net.Proxy { *; }
-keep class java.net.Proxy$Type { *; }

# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile
