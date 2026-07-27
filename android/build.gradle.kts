buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 빌드 디렉토리 경로 커스텀 지정
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    project.evaluationDependsOn(":app")

    // 일부 플러그인(amplitude_flutter 등)이 오래된 compileSdk에 고정되어 있어
    // androidx 최신 의존성과 충돌(AAR metadata check 실패)하는 것을 방지
    // (:app은 evaluationDependsOn(":app") 때문에 이미 평가되어 afterEvaluate가 실패하므로 제외)
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let { ext ->
                (ext as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
            }
        }
    }
}