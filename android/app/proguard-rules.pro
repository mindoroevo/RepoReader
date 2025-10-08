# ProGuard / R8 rules for Release shrink
# (Aktuell Shrinking deaktiviert; wenn in build.gradle aktiviert wird, dienen diese Regeln als Startpunkt.)

# Behalte Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Play Core (SplitCompat / SplitInstall) classes referenced by Flutter deferred components manager
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Behalte TTS reflection uses
-keep class android.speech.tts.** { *; }

# (Optional) Logging entfernen – Beispiel:
# -assumenosideeffects class android.util.Log { *; }
