-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

-keep class com.squareup.okhttp3.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.biometric.** { *; }
-keepattributes SourceFile,LineNumberTable
# Play Core is referenced by the Flutter engine but not shipped (no deferred components).
-dontwarn com.google.android.play.core.**
