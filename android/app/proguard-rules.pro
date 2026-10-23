# ML Kit: usiamo solo il lettore per l'alfabeto latino; gli altri (cinese, giapponese...) non sono inclusi.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit carica alcuni suoi pezzi "per nome" mentre l'app gira: R8 non lo sa e li toglierebbe.
# Così li teniamo tutti (risolve l'errore "getClass() on a null object reference").
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }
