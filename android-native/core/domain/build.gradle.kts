// Pure Kotlin/JVM module — no Android SDK dependency by design (see
// README.md "M0 verification"). This is what lets prayer-time math and
// recurrence logic be unit-tested without an Android toolchain, and is
// the KMP-ready core if iOS is ever pursued.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation(libs.adhan)
    implementation(libs.kotlinx.datetime)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit5.api)
    testImplementation(libs.junit5.params)
    testRuntimeOnly(libs.junit5.engine)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.truth)
}

tasks.test {
    useJUnitPlatform()
}
