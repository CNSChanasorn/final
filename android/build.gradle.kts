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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Patch for Legacy Libraries (flutter_tflite)
subprojects {
    if (project.name == "flutter_tflite") {
        val fixNamespace = {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                android.namespace = "sq.flutter.tflite"
            }
        }

        if (project.state.executed) {
            fixNamespace()
        } else {
            project.afterEvaluate { fixNamespace() }
        }
    }
}
