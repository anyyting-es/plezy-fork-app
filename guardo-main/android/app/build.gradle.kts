plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mpvVersion = "v1.0.7"
val mpvDir = layout.buildDirectory.dir("libmpv").get().asFile
val mpvAar = "libmpv-release.aar"

val downloadLibmpv by tasks.registering {
  val stamp = File(mpvDir, ".version")
  outputs.upToDateWhen { stamp.exists() && stamp.readText().trim() == mpvVersion }
  doLast {
    mpvDir.mkdirs()
    val url = "https://github.com/edde746/libmpv-android/releases/download/$mpvVersion/$mpvAar"
    exec { commandLine("curl", "-sfL", url, "-o", File(mpvDir, mpvAar).absolutePath) }
    stamp.writeText(mpvVersion)
  }
}

val assVersion = "fp-3"
val assDir = layout.buildDirectory.dir("libass").get().asFile
val assAars = listOf("lib_ass-release.aar", "lib_ass_kt-release.aar", "lib_ass_media-release.aar")

val downloadLibass by tasks.registering {
  val stamp = File(assDir, ".version")
  outputs.upToDateWhen { stamp.exists() && stamp.readText().trim() == assVersion }
  doLast {
    assDir.mkdirs()
    val baseUrl = "https://github.com/edde746/libass-android/releases/download/$assVersion"
    assAars.forEach { name ->
      val dest = File(assDir, name)
      exec { commandLine("curl", "-sfL", "$baseUrl/$name", "-o", dest.absolutePath) }
    }
    stamp.writeText(assVersion)
  }
}

val doviVersion = "2.3.1"
val doviDir = layout.buildDirectory.dir("libdovi").get().asFile
val doviAbis = mapOf(
  "arm64-v8a" to "aarch64-linux-android",
  "armeabi-v7a" to "armv7-linux-androideabi",
  "x86" to "i686-linux-android",
  "x86_64" to "x86_64-linux-android"
)

val downloadLibdovi by tasks.registering {
  val stamp = File(doviDir, ".version")
  outputs.upToDateWhen { stamp.exists() && stamp.readText().trim() == doviVersion }
  doLast {
    doviDir.mkdirs()
    val baseUrl = "https://github.com/edde746/libdovi-builds/releases/download/v$doviVersion"
    doviAbis.forEach { (abi, triple) ->
      val archive = File(doviDir, "$triple.tar.gz")
      exec { commandLine("curl", "-sfL", "$baseUrl/libdovi-$triple.tar.gz", "-o", archive.absolutePath) }
      val outDir = File(doviDir, "$abi/lib")
      outDir.mkdirs()
      exec { commandLine("tar", "-xzf", archive.absolutePath, "-C", outDir.absolutePath) }
      archive.delete()
    }
    stamp.writeText(doviVersion)
  }
}

android {
    namespace = "com.example.anityng"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.anityng"
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
            stl = "c++_shared"
        }
        
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DDOVI_ENABLE_LIBDOVI=ON",
                    "-DDOVI_LIBDOVI_PREBUILT_ROOT=${doviDir.absolutePath}"
                )
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            pickFirsts.add("lib/*/libc++_shared.so")
            pickFirsts.add("lib/*/libmpv.so")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.setSrcDirs(listOf("src/main/jniLibs"))
        }
    }
}

flutter {
    source = "../.."
}

// Download libdovi before any CMake/native build task
tasks.matching { it.name.contains("CMake") || it.name.contains("externalNative") }.configureEach {
  dependsOn(downloadLibdovi)
}

// Download libmpv and libass AARs before compilation
tasks.matching { it.name.startsWith("pre") && it.name.endsWith("Build") }.configureEach {
  dependsOn(downloadLibmpv)
  dependsOn(downloadLibass)
}

dependencies {
  implementation(files(File(mpvDir, mpvAar)))
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
  assAars.forEach { implementation(files(File(assDir, it))) }
}
