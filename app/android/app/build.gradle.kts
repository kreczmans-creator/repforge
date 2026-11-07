plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tempest.repforge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time on API 24-25).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tempest.repforge"
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

    // WP 14 release signing. The release workflow (.github/workflows/release.yml)
    // supplies these four values from repository secrets; they are read from
    // Gradle properties (-PRF_...) or the environment. No keystore or password
    // is ever committed (engineering standards, section 9). When none of
    // the four is set the release build type keeps the debug signing below, so local
    // builds and the existing workflows behave exactly as before. Setting only
    // some of them is an error.
    fun rfSigning(name: String): String? =
        (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
            ?: System.getenv(name)?.takeIf { it.isNotBlank() }

    val rfKeystorePath = rfSigning("RF_KEYSTORE_PATH")
    val rfKeystorePassword = rfSigning("RF_KEYSTORE_PASSWORD")
    val rfKeyAlias = rfSigning("RF_KEY_ALIAS")
    val rfKeyPassword = rfSigning("RF_KEY_PASSWORD")
    val rfSigningValues = mapOf(
        "RF_KEYSTORE_PATH" to rfKeystorePath,
        "RF_KEYSTORE_PASSWORD" to rfKeystorePassword,
        "RF_KEY_ALIAS" to rfKeyAlias,
        "RF_KEY_PASSWORD" to rfKeyPassword,
    )
    val rfMissing = rfSigningValues.filterValues { it == null }.keys
    // None set: silent debug fallback. Some set: a half-configured release
    // build must fail loudly rather than quietly ship debug-signed.
    if (rfMissing.isNotEmpty() && rfMissing.size < rfSigningValues.size) {
        throw GradleException(
            "Incomplete release signing configuration; missing: " +
                rfMissing.joinToString(", ") +
                ". Set all four RF_* values or none.",
        )
    }
    val rfReleaseSigned = rfMissing.isEmpty()

    signingConfigs {
        if (rfReleaseSigned) {
            create("release") {
                storeFile = file(rfKeystorePath!!)
                storePassword = rfKeystorePassword
                keyAlias = rfKeyAlias
                keyPassword = rfKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Release signing when all four RF_* values are present; otherwise
            // the debug keys, so `flutter run --release` and the CI R8 check work.
            signingConfig = if (rfReleaseSigned) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
