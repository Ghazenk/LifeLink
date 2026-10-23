import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningFile = rootProject.file("key.properties")
val releaseSigning = Properties().apply {
    if (releaseSigningFile.isFile) FileInputStream(releaseSigningFile).use { load(it) }
}
val releaseApplicationId = providers.gradleProperty("lifelinkApplicationId").orNull
    ?: "com.example.lifelink"

android {
    namespace = "com.example.lifelink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = releaseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningFile.isFile) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile", ""))
                storePassword = releaseSigning.getProperty("storePassword", "")
                keyAlias = releaseSigning.getProperty("keyAlias", "")
                keyPassword = releaseSigning.getProperty("keyPassword", "")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (releaseApplicationId == "com.example.lifelink" ||
            !Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*){2,}$").matches(releaseApplicationId)) {
            throw GradleException("Set a unique production application ID with -PlifelinkApplicationId=... before release.")
        }
        if (!releaseSigningFile.isFile ||
            listOf("storeFile", "storePassword", "keyAlias", "keyPassword").any {
                releaseSigning.getProperty(it).isNullOrBlank()
            }) {
            throw GradleException("Create android/key.properties with a private release keystore before building a release.")
        }
        if (!file(releaseSigning.getProperty("storeFile")).isFile) {
            throw GradleException("The configured release keystore file does not exist.")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
