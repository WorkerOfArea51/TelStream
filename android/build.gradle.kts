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
                    // Required: file_picker v8.3.7 needs compileSdk >= 36.
                    // Keep this override until file_picker is upgraded or app's compileSdk is bumped.
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

    project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
        }
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
