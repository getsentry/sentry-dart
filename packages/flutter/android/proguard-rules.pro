# Keep classes and their nested classes accessed via JNI from the `package:jni`-generated
# bindings in lib/src/native/java/binding.dart. This block is generated from the `classes:`
# entries in ffi-jni.yaml by scripts/generate-sentry-java-proguard.sh -- do not hand-edit
# the block below, run the script again after changing ffi-jni.yaml instead.
# AUTO-GENERATED-START
-keep,includedescriptorclasses class io.sentry.android.core.SentryAndroid { *; }
-keep,includedescriptorclasses class io.sentry.android.core.SentryAndroid$* { *; }
-keep,includedescriptorclasses class io.sentry.android.core.SentryAndroidOptions { *; }
-keep,includedescriptorclasses class io.sentry.android.core.SentryAndroidOptions$* { *; }
-keep,includedescriptorclasses class io.sentry.android.core.InternalSentrySdk { *; }
-keep,includedescriptorclasses class io.sentry.android.core.InternalSentrySdk$* { *; }
-keep,includedescriptorclasses class io.sentry.android.core.BuildConfig { *; }
-keep,includedescriptorclasses class io.sentry.android.core.BuildConfig$* { *; }
-keep,includedescriptorclasses class io.sentry.android.replay.ReplayIntegration { *; }
-keep,includedescriptorclasses class io.sentry.android.replay.ReplayIntegration$* { *; }
-keep,includedescriptorclasses class io.sentry.android.replay.ScreenshotRecorderConfig { *; }
-keep,includedescriptorclasses class io.sentry.android.replay.ScreenshotRecorderConfig$* { *; }
-keep,includedescriptorclasses class io.sentry.flutter.SentryFlutterPlugin { *; }
-keep,includedescriptorclasses class io.sentry.flutter.SentryFlutterPlugin$* { *; }
-keep,includedescriptorclasses class io.sentry.flutter.ReplayRecorderCallbacks { *; }
-keep,includedescriptorclasses class io.sentry.flutter.ReplayRecorderCallbacks$* { *; }
-keep,includedescriptorclasses class io.sentry.Sentry { *; }
-keep,includedescriptorclasses class io.sentry.Sentry$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryOptions { *; }
-keep,includedescriptorclasses class io.sentry.SentryOptions$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryReplayOptions { *; }
-keep,includedescriptorclasses class io.sentry.SentryReplayOptions$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryReplayEvent { *; }
-keep,includedescriptorclasses class io.sentry.SentryReplayEvent$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryEvent { *; }
-keep,includedescriptorclasses class io.sentry.SentryEvent$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryBaseEvent { *; }
-keep,includedescriptorclasses class io.sentry.SentryBaseEvent$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryLevel { *; }
-keep,includedescriptorclasses class io.sentry.SentryLevel$* { *; }
-keep,includedescriptorclasses class io.sentry.Hint { *; }
-keep,includedescriptorclasses class io.sentry.Hint$* { *; }
-keep,includedescriptorclasses class io.sentry.ReplayRecording { *; }
-keep,includedescriptorclasses class io.sentry.ReplayRecording$* { *; }
-keep,includedescriptorclasses class io.sentry.Breadcrumb { *; }
-keep,includedescriptorclasses class io.sentry.Breadcrumb$* { *; }
-keep,includedescriptorclasses class io.sentry.ScopesAdapter { *; }
-keep,includedescriptorclasses class io.sentry.ScopesAdapter$* { *; }
-keep,includedescriptorclasses class io.sentry.Scope { *; }
-keep,includedescriptorclasses class io.sentry.Scope$* { *; }
-keep,includedescriptorclasses class io.sentry.ScopeCallback { *; }
-keep,includedescriptorclasses class io.sentry.ScopeCallback$* { *; }
-keep,includedescriptorclasses class io.sentry.protocol.User { *; }
-keep,includedescriptorclasses class io.sentry.protocol.User$* { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SentryId { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SentryId$* { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SdkVersion { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SdkVersion$* { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SentryPackage { *; }
-keep,includedescriptorclasses class io.sentry.protocol.SentryPackage$* { *; }
-keep,includedescriptorclasses class io.sentry.rrweb.RRWebOptionsEvent { *; }
-keep,includedescriptorclasses class io.sentry.rrweb.RRWebOptionsEvent$* { *; }
-keep,includedescriptorclasses class io.sentry.rrweb.RRWebEvent { *; }
-keep,includedescriptorclasses class io.sentry.rrweb.RRWebEvent$* { *; }
-keep,includedescriptorclasses class io.sentry.SentryTraceHeader { *; }
-keep,includedescriptorclasses class io.sentry.SentryTraceHeader$* { *; }
# AUTO-GENERATED-END

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
