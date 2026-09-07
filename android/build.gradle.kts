import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

// Keep Kotlin at 17 to match app/Java 17 plugins (e.g. flutter_jailbreak_detection_plus).
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// stripe_android compileOnly-depends on stripe-android-issuing-push-provisioning,
// whose POM pulls Google's private play-services-tapandpay. AGP 9 release lint
// resolves that graph and fails. This app only uses PaymentSheet, not push
// provisioning / Google Wallet issuing.
subprojects {
    if (name != "stripe_android") return@subprojects
    configurations.configureEach {
        exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
    }
    tasks.configureEach {
        if (name.startsWith("lintVital")) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
