// Scheda dell'app: nome del pacchetto, versioni di Android supportate e librerie usate.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "it.mastro.provalettura"
    compileSdk = 34

    defaultConfig {
        applicationId = "it.mastro.provalettura"
        minSdk = 28          // Android 9 o più recente
        targetSdk = 34
        versionCode = 1
        versionName = "0.1-prova"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // ML Kit: il lettore di testo con IA che gira tutto sul telefono, senza internet.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    // Pezzi standard di Android: schermate, scelta foto, fotocamera.
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("androidx.core:core-ktx:1.13.1")
}
