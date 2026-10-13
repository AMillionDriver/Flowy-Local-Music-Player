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

subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val getNamespaceMethod = androidExt.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val currentNamespace = getNamespaceMethod?.invoke(androidExt) as? String

            if (currentNamespace.isNullOrEmpty()) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                val manifestPackage = if (manifestFile.exists()) {
                    Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifestFile.readText())
                        ?.groupValues?.get(1)
                } else null

                val targetNamespace = manifestPackage
                    ?: if (project.name == "on_audio_query_android") {
                        "com.lucasjosino.on_audio_query"
                    } else {
                        "com.example.${project.name.replace('-', '_')}"
                    }

                val setNamespaceMethod = androidExt.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1 && it.parameterTypes[0] == String::class.java
                }
                setNamespaceMethod?.invoke(androidExt, targetNamespace)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
