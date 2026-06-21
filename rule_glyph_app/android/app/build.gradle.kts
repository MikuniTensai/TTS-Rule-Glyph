import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterProjectDir = rootProject.projectDir.parentFile
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
val dartExecutable = if (flutterSdkPath != null) {
    if (System.getProperty("os.name").lowercase().contains("windows")) {
        "$flutterSdkPath\\bin\\dart.bat"
    } else {
        "$flutterSdkPath/bin/dart"
    }
} else {
    "dart"
}

val syncLevelsJsonForFlutter by tasks.registering(Exec::class) {
    group = "build"
    description = "Splits assets/levels.json into Android level asset folders before packaging."
    workingDir = flutterProjectDir
    commandLine(dartExecutable, "run", "bin/split_json.dart")
    inputs.file(file("${flutterProjectDir.path}/assets/levels.json"))
    outputs.dir(file("${flutterProjectDir.path}/assets/levels"))
}

android {
    namespace = "io.dreamworks.tts"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.dreamworks.tts"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Local fallback only. Store builds must provide android/key.properties.
                signingConfigs.getByName("debug")
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

tasks.matching { it.name == "preBuild" || it.name.startsWith("compileFlutterBuild") }.configureEach {
    dependsOn(syncLevelsJsonForFlutter)
}
