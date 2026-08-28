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

// Workaround: another_telephony (real bank SMS interception) pins its
// Kotlin compilation to JVM target 1.8 but never sets Java compatibility
// itself, so it inherits this project's newer Java default (11) — AGP's
// consistency check then fails on the Java/Kotlin target mismatch. Align
// Java down to 1.8 for this one subproject to match its Kotlin target.
subprojects {
    if (project.name == "another_telephony") {
        plugins.withId("com.android.library") {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
                android.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
