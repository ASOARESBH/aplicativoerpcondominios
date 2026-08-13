# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Biometric
-keep class androidx.biometric.** { *; }

# Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**


# R8 / Flutter: o motor contém suporte opcional a módulos dinâmicos da Play
# Store. Este APK não usa deferred components nem feature delivery, portanto as
# referências não carregadas não devem interromper a minificação de release.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# google_mlkit_text_recognition inclui referências opcionais para os modelos de
# Chinês, Devanagari, Japonês e Coreano. O aplicativo usa OCR Latin/Português;
# as classes destes idiomas não são empacotadas e são suprimidas de forma
# explícita para que R8 não interrompa o build. Se algum deles for adotado no
# futuro, inclua a dependência Android do respectivo modelo em build.gradle.kts.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
