import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
//subprojects {
//    project.evaluationDependsOn(":app")
//}

subprojects {
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val androidExtension = project.extensions.getByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
                androidExtension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                androidExtension.compileOptions.targetCompatibility = JavaVersion.VERSION_17

                if (androidExtension.namespace == null) {
                    androidExtension.namespace = project.group.toString()
                }

                if (project.name == "flutter_inappwebview_android") {
                    androidExtension.buildTypes.getByName("release").isMinifyEnabled = false
                }
            }
        }
    }
}

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = JavaVersion.VERSION_17.toString()
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
