import java.io.File


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
                @Suppress("DEPRECATION")
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



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
