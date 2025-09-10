plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.padel_scoreboard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Este applicationId é o "base". Os flavors abaixo vão sobrepor com IDs únicos.
        applicationId = "com.example.padel_scoreboard"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---- FLAVORS ----
    // Ter duas apps instaladas em paralelo: admin e viewer
    flavorDimensions += "mode"
    productFlavors {
        create("admin") {
            dimension = "mode"
            applicationId = "com.nps.padel.admin"      // ← ID ÚNICO
            versionNameSuffix = "-admin"
            resValue("string", "app_name", "ADMIN IIOpenOuriços") // ← nome da app (é usado no Manifest)
        }
        create("scorer") {
            dimension = "mode"
            applicationId = "com.nps.padel.scorer"     // ← ID ÚNICO
            versionNameSuffix = "-scorer"
            resValue("string", "app_name", "II Open Ouriços")
        }
    }

    buildTypes {
        release {
            // Assinatura: ajustar para as tuas chaves quando fores publicar
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
