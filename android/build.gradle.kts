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

    val configureSubproject: () -> Unit = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            // 1. Force compileSdk >= 34 for legacy libraries requiring newer Android APIs
            try {
                val getCompileSdkMethod = androidExt.javaClass.methods.firstOrNull {
                    it.name == "getCompileSdk" && it.parameterCount == 0
                } ?: androidExt.javaClass.methods.firstOrNull {
                    it.name == "getCompileSdkVersion" && it.parameterCount == 0
                }
                val currentCompileSdk = getCompileSdkMethod?.invoke(androidExt)
                val compileSdkInt = when (currentCompileSdk) {
                    is Number -> currentCompileSdk.toInt()
                    is String -> currentCompileSdk.removePrefix("android-").toIntOrNull()
                    else -> null
                }

                if (compileSdkInt == null || compileSdkInt < 34 || project.name == "on_audio_query_android") {
                    val setCompileSdkMethod = androidExt.javaClass.methods.firstOrNull {
                        it.name == "setCompileSdkVersion" && it.parameterCount == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
                    } ?: androidExt.javaClass.methods.firstOrNull {
                        it.name == "compileSdkVersion" && it.parameterCount == 1 && it.parameterTypes[0] == Int::class.javaPrimitiveType
                    } ?: androidExt.javaClass.methods.firstOrNull {
                        it.name == "setCompileSdk" && it.parameterCount == 1 && it.parameterTypes[0] == Integer::class.java
                    }
                    setCompileSdkMethod?.invoke(androidExt, 34)
                }
            } catch (_: Exception) {}

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

    if (project.state.executed) {
        configureSubproject()
    } else {
        afterEvaluate { configureSubproject() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
