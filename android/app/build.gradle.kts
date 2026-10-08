import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle plugin must be applied after Android and Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase is opt-in: only applied when a google-services.json is present,
    // so the default build has no Firebase dependency at all.
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.crashlytics") apply false
}

/// Firebase is only wired up when the app is configured for it. This mirrors
/// `AppConfig.enableFirebase` on the Dart side and keeps a plain checkout
/// buildable with no google-services.json.
val enableFirebase = project.hasProperty("enableFirebase") &&
    project.property("enableFirebase").toString().toBoolean()

if (enableFirebase) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

/// Values injected as `--dart-define`, read here so the AndroidManifest and the
/// Dart layer agree without duplicating them.
val dartDefines = mutableMapOf<String, String>()
val dartDefineList = (project.findProperty("dart-defines") as String?)?.split(",") ?: emptyList()
for (entry in dartDefineList) {
    if (entry.isBlank()) continue
    val decoded = String(android.util.Base64.decode(entry, android.util.Base64.DEFAULT))
    val separator = decoded.indexOf('=')
    if (separator <= 0) continue
    dartDefines[decoded.substring(0, separator)] = decoded.substring(separator + 1)
}

val admobAppId = dartDefines["ADMOB_APP_ID"]
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.mergedrop.merge_drop"
    compileSdk = 35

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mergedrop.merge_drop"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        // Surfaced to AndroidManifest.xml so the AdMob app id never has to be
        // hardcoded in a committed resource.
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    buildTypes {
        debug {
            isDebuggable = true
        }
        release {
            // Signed with the debug key by default so `flutter run --release`
            // works out of the box; supply a real keystore for the store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        resources.excludes += setOf(
            "META-INF/DEPENDENCIES",
            "META-INF/LICENSE",
            "META-INF/LICENSE.txt",
            "META-INF/NOTICE",
            "META-INF/NOTICE.txt",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase is optional; nothing here is required for the game to run.
    if (enableFirebase) {
        implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
        implementation("com.google.firebase:firebase-analytics")
        implementation("com.google.firebase:firebase-crashlytics")
    }
    implementation("com.google.android.gms:play-services-ads-identifier:18.1.0")
}
