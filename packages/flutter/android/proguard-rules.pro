# Keep classes used by JNI
-keep class io.sentry.** { *; }
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.Bitmap$Config { *; }
-keep class java.net.Proxy { *; }
-keep class java.net.Proxy$Type { *; }

# To ensure that stack traces is unambiguous
# https://developer.android.com/studio/build/shrink-code#decode-stack-trace
-keepattributes LineNumberTable,SourceFile
