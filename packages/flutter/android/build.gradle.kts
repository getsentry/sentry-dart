import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.3.2")
        // Keep in sync with `kotlinVersion` below; a Kotlin DSL `buildscript`
        // block cannot read a value declared in the body of the script.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.10")
    }
}

val kotlinVersion = "2.3.10"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply(plugin = "com.android.library")

// AGP 9 compiles Kotlin itself, so the standalone Kotlin Gradle Plugin is only
// applied on older AGP. `android.builtInKotlin` lets a project opt back out of
// AGP 9's built-in Kotlin, so it has to be honored alongside the AGP version.
//
// This file is Kotlin DSL rather than Groovy on purpose: Flutter detects
// plugins that apply KGP by running a regex over this file's source text (see
// FlutterPluginUtils.getSubprojectPluginState), not by inspecting the build at
// runtime. Its Groovy regex matches a line starting with `apply plugin:
// 'kotlin-android'` even when that line is unreachable, while its Kotlin regex
// only looks inside a `plugins {}` block. A conditional `apply(plugin = ...)`
// here is the shape Flutter documents for plugins that still support AGP < 9.
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
val builtInKotlin = agpMajor >= 9 && project.findProperty("android.builtInKotlin") != "false"

if (!builtInKotlin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

configure<LibraryExtension> {
    compileSdk = 37
    namespace = "io.sentry.flutter"

    // `src/main/kotlin` needs no explicit srcDir: both the standalone Kotlin
    // plugin and AGP 9's built-in Kotlin register it by convention.

    defaultConfig {
        minSdk = 21

        ndk {
            // Flutter does not currently support building for x86 Android (See Issue 9253).
            abiFilters += listOf("armeabi-v7a", "x86_64", "arm64-v8a")
        }
    }

    buildTypes {
        getByName("release") {
            consumerProguardFiles("proguard-rules.pro")
        }
        getByName("debug") {
            consumerProguardFiles("proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}

// The extension-level `compilerOptions` DSL needs KGP 2.0+. Flutter 3.24-era
// apps (and this repo's min_version_test) still ship KGP 1.8.x, which only has
// `kotlinOptions`, so fall back to it when `compilerOptions` is unavailable.
val kotlinExtension = extensions.findByName("kotlin")

if (kotlinExtension is KotlinAndroidProjectExtension &&
    kotlinExtension.javaClass.methods.any { it.name == "compilerOptions" }
) {
    kotlinExtension.compilerOptions {
        jvmTarget.set(JvmTarget.JVM_1_8)
    }
} else {
    // Set through reflection so this branch cannot fail to compile or throw
    // against a KGP whose types differ from the ones this script was compiled
    // against.
    val legacyOptions = (extensions.getByName("android") as ExtensionAware)
        .extensions
        .findByName("kotlinOptions")
    legacyOptions
        ?.javaClass
        ?.methods
        ?.firstOrNull {
            it.name == "setJvmTarget" &&
                it.parameterTypes.size == 1 &&
                it.parameterTypes[0] == String::class.java
        }?.invoke(legacyOptions, JavaVersion.VERSION_1_8.toString())
}

dependencies {
    "api"("io.sentry:sentry-android:8.53.0")
    "debugImplementation"("io.sentry:sentry-spotlight:8.53.0")
    "implementation"("org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlinVersion")

    // Required -- JUnit 4 framework
    "testImplementation"("junit:junit:4.13.2")
}
