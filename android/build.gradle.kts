allprojects {
    repositories {
        google()
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        all {
            if (this is MavenArtifactRepository) {
                val urlStr = url.toString()
                if (urlStr.contains("plugins.gradle.org")) {
                    setUrl(uri("https://maven.aliyun.com/repository/gradle-plugin"))
                } else if (urlStr.contains("repo.maven.apache.org") || urlStr.contains("repo1.maven.org")) {
                    setUrl(uri("https://maven-central.storage-download.googleapis.com/maven2/"))
                }
            }
        }
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
