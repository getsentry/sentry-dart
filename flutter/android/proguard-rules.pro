-keep class io.sentry.flutter.** { *; }

# JNI generated binding code (keep up to date with ffi-jni.yaml).
-keep class java.io.File
-keep class io.sentry.android.replay.Recorder
-keep class io.sentry.android.replay.ScreenshotRecorderConfig
-keep class io.sentry.android.replay.ReplayIntegration

# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile
