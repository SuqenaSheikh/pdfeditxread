# Flutter / Play Core (deferred components stubs)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# google_mlkit_text_recognition references optional script packs that are not
# bundled. Suppress R8 missing-class errors for those optional modules.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Syncfusion PDF / PDF Viewer
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**
