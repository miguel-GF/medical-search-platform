plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pruevia.pruevia_patient"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pruevia.pruevia_patient"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A release artifact must never fall back to the debug keystore. Apart
    // from exposing a non-production trust identity, that would let a
    // seemingly legitimate package be replaced or make secure updates
    // impossible. CI/release machines provide these values as secrets.
    val releaseStorePath = providers.environmentVariable("PRUEVIA_RELEASE_STORE_FILE").orNull
    val releaseStorePassword = providers.environmentVariable("PRUEVIA_RELEASE_STORE_PASSWORD").orNull
    val releaseKeyAlias = providers.environmentVariable("PRUEVIA_RELEASE_KEY_ALIAS").orNull
    val releaseKeyPassword = providers.environmentVariable("PRUEVIA_RELEASE_KEY_PASSWORD").orNull
    val releaseSigningConfigured = listOf(
        releaseStorePath,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { !it.isNullOrBlank() }
    val releaseTaskRequested = gradle.startParameter.taskNames.any {
        val task = it.substringAfterLast(':').lowercase()
        task.contains("release") || task in setOf("assemble", "bundle", "build")
    }

    if (releaseTaskRequested && !releaseSigningConfigured) {
        throw GradleException(
            "Production Android release signing is not configured. " +
                "Set PRUEVIA_RELEASE_STORE_FILE, PRUEVIA_RELEASE_STORE_PASSWORD, " +
                "PRUEVIA_RELEASE_KEY_ALIAS and PRUEVIA_RELEASE_KEY_PASSWORD."
        )
    }

    if (releaseSigningConfigured) {
        signingConfigs {
            create("prueviaRelease") {
                storeFile = file(requireNotNull(releaseStorePath))
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // With no production credentials this remains unsigned (and a
            // release task fails above), never debug-signed.
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("prueviaRelease")
            } else {
                signingConfig = null
            }
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
