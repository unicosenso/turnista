// Dice a Gradle (il "costruttore" dell'app) dove scaricare i pezzi e quali moduli compongono il progetto.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "ProvaLettura"
include(":app")
