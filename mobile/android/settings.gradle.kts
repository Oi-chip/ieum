pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            // local.properties에 Flutter SDK 경로가 한글로 저장될 수 있습니다.
            // 파일을 UTF-8로 읽어야 "까치" 같은 한글 폴더명이 깨지지 않습니다.
            file("local.properties").reader(Charsets.UTF_8).use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
