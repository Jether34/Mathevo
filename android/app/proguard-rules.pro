# The ML Kit Flutter plugin compileOnly references optional script recognizers.
# Mathevo currently initializes the Latin recognizer; these language-specific
# classes are intentionally absent from the APK.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
