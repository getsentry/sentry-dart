-keep class io.sentry.flutter.** { *; }
-keepclassmembers class io.sentry.flutter.** { *; }

# Keep replay integration classes used by JNI
-keep class io.sentry.android.replay.** { *; }

# Keep bitmap classes used by JNI
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.Bitmap$Config { *; }

# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile
