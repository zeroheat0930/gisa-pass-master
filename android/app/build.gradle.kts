import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.gisapass.gisa_pass_master"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 가 core library desugaring 을 요구한다.
        // 없으면 Android 빌드가 checkDebugAarMetadata 에서 실패한다.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.gisapass.gisa_pass_master"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // Play Console 이 "최적화된 리소스 축소가 사용 설정되지 않음" 으로
            // 지적한 부분. 코드 축소를 켜야 리소스 축소도 켤 수 있다.
            //
            // Flutter 는 자체 ProGuard 규칙(engine·plugin 유지)을 기본으로
            // 넣어주므로 별도 규칙 파일 없이도 동작한다. 다만 리플렉션을 쓰는
            // 플러그인이 있으면 릴리즈에서만 깨질 수 있어 **AAB 를 올리기 전에
            // 실기기/에뮬레이터에서 반드시 한 번 실행해 볼 것.**
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // core library desugaring 런타임 (flutter_local_notifications 요구사항)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
