-keep class io.sentry.flutter.** { *; }
-keep class io.sentry.** { *; }

# Keep bitmap classes used by JNI
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.Bitmap$Config { *; }

# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile
