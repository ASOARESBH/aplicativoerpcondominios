plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// O projeto continua compilando sem Firebase. Ao adicionar o arquivo oficial
// android/app/google-services.json, o plugin é ativado automaticamente.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "br.com.erpcondominios"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Obrigatório para flutter_local_notifications (Java 8+ API desugaring)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.erpcondominios"
        minSdk = flutter.minSdkVersion  // Android 5.0+ (suporte a biometria e flutter_secure_storage)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Configurar keystore antes de publicar na Play Store
            // signingConfig = signingConfigs.getByName("release")
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Remove sufixos para debug para evitar conflito de applicationId
            // applicationIdSuffix = ".debug"
            // versionNameSuffix = "-debug"
        }
    }
}

dependencies {
    // ✅ Biblioteca de desugaring obrigatória para flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    // `kotlinOptions` virou erro no Kotlin 2.2+; usar compilerOptions.
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
