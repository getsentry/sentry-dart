group = "io.sentry.flutter.webview"

plugins {
    id("com.android.library")
}

android {
    namespace = "io.sentry.flutter.webview"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":webview_flutter_android"))
    implementation("androidx.webkit:webkit:1.15.0")
}
