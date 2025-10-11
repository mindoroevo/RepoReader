import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mindoroevolution.reporeader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Benötigt für Abhängigkeiten wie flutter_local_notifications (Java 8+ APIs)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "com.mindoroevolution.reporeader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            debugSymbolLevel = "SYMBOL_TABLE"
        }
    }

    // --- Signing Config (loaded from android/key.properties if present) ---
    val keystoreProperties = Properties()
    // Pfad korrigiert: rootProject ist bereits das android/ Verzeichnis. Vorher wurde fälschlich android/android/... gesucht.
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storePath = keystoreProperties.getProperty("storeFile")
                var resolvedStoreFile = file(storePath)
                // Falls der Pfad relativ zum Modul (android/app) nicht existiert, versuche Parent (android/)
                if (!resolvedStoreFile.exists()) {
                    val parentCandidate = File(projectDir.parentFile, storePath)
                    if (parentCandidate.exists()) {
                        println("[Signing] Adjusted keystore path to parent directory: ${parentCandidate.path}")
                        resolvedStoreFile = parentCandidate
                    }
                }
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                println("[Signing] Using RELEASE keystore: ${storeFile?.path} (alias=${keyAlias})")
                if (storeFile != null && !storeFile!!.exists()) {
                    println("[Signing][WARN] Configured storeFile does not exist ON DISK (after adjustment) -> build will fail. path=${storeFile!!.path}")
                }
            } else {
                // Fallback: debug signing wenn keine key.properties vorhanden
                // (Play Store Upload REJECTS this – unbedingt eigene Keys anlegen!)
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
                println("[Signing][FALLBACK] key.properties fehlt -> benutze DEBUG keystore (NICHT für Release geeignet)")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Standard: Kein Code Shrinking aktiv (stabiler für erste Veröffentlichung)
            // Später optional aktivieren: isMinifyEnabled = true; shrinkResources = true
            // und dann proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            // Unverändert
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring für neuere Java APIs (java.time etc.)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.android.play:feature-delivery:2.1.0")
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:core-common:2.0.4")
    compileOnly("com.google.android.play:core:1.10.3")
    // Play Core Library (benötigt weil Flutter Embedding SplitCompat-Klassen referenziert → R8 Missing Class Fix)
    // Play Core entfernt: nicht mit targetSdk 34 kompatibel.
}
