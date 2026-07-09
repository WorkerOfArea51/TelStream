import java.io.File

// Automatically patch media_kit_libs_android_video to download full libmpv binaries
val patchMediaKitLibsAndroidVideo = {
    try {
        val userHome = System.getProperty("user.home")
        val localAppData = System.getenv("LOCALAPPDATA")
        val cacheDirs = mutableListOf<File>()
        
        // Add standard pub cache locations
        val pubCacheEnv = System.getenv("PUB_CACHE")
        if (!pubCacheEnv.isNullOrEmpty()) {
            cacheDirs.add(File(pubCacheEnv))
        }
        if (!localAppData.isNullOrEmpty()) {
            cacheDirs.add(File(localAppData, "Pub/Cache"))
        }
        cacheDirs.add(File(userHome, ".pub-cache"))

        var patched = false
        for (cacheDir in cacheDirs) {
            val hostedDir = File(cacheDir, "hosted/pub.dev")
            if (hostedDir.exists()) {
                val libDirs = hostedDir.listFiles { _, name -> name.startsWith("media_kit_libs_android_video-") }
                if (libDirs != null) {
                    for (libDir in libDirs) {
                        val gradleFile = File(libDir, "android/build.gradle")
                        if (gradleFile.exists()) {
                            var content = gradleFile.readText()
                            if (content.contains("v1.1.7/default-")) {
                                content = content.replace("v1.1.7/default-arm64-v8a.jar", "v1.1.11/full-arm64-v8a.jar")
                                                 .replace("83df25b61193af8fa815e373143ac9af", "86f2c8faeb66af1878b3a16f67831cb3")
                                                 .replace("v1.1.7/default-armeabi-v7a.jar", "v1.1.11/full-armeabi-v7a.jar")
                                                 .replace("22e21526fefc0a2b8f17adbec9f57590", "93542d40e44f3afad3aa773674e8eaa5")
                                                 .replace("v1.1.7/default-x86_64.jar", "v1.1.11/full-x86_64.jar")
                                                 .replace("6fa26bf0459b11f1c0b0dbc29e5b940d", "44b7efdbaf3626d6b24afaf5d497a369")
                                                 .replace("v1.1.7/default-x86.jar", "v1.1.11/full-x86.jar")
                                                 .replace("0d742b756dc9d1fcd84ea271d8b68f32", "e69a9bbd7fb587deb33dd10fecc2fecc")
                                                 .replace("v1.1.7", "v1.1.11")
                                gradleFile.writeText(content)
                                println("Auto-patched media_kit_libs_android_video build.gradle to use full v1.1.11 libmpv libraries.")
                                patched = true
                            }
                        }
                    }
                }
            }
            if (patched) break
        }
    } catch (e: Exception) {
        throw GradleException("Failed to auto-patch media_kit_libs_android_video build.gradle: ${e.message}")
    }
    if (!patched) {
        throw GradleException("media_kit_libs_android_video patch failed: Could not find the expected v1.1.7 libraries in pub cache. The build cannot proceed as video playback would be broken.")
    }
}
patchMediaKitLibsAndroidVideo()

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    val configureAndroidNamespace: Project.() -> Unit = {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android")
            if (android != null) {
                val baseExtension = android as? com.android.build.gradle.BaseExtension
                if (baseExtension != null) {
                    // Force subprojects to compile with Android SDK 36 to satisfy modern dependency requirements
                    baseExtension.compileSdkVersion(36)
                    
                    if (baseExtension.namespace.isNullOrEmpty()) {
                        val groupName = project.group.toString()
                        baseExtension.namespace = if (groupName.isNotEmpty()) groupName else "com.darkmatter.telstream.${project.name.replace("-", "_").replace(":", "_")}"
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        project.configureAndroidNamespace()
    } else {
        project.afterEvaluate { configureAndroidNamespace() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
