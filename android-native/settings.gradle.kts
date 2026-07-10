pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "awkati"

// core:domain has zero Android dependencies (pure Kotlin/JVM) and is the
// only module buildable/testable without an Android SDK. See README.md.
include(":core:domain")
include(":core:designsystem")
include(":app")
