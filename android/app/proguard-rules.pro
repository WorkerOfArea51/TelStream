# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Tdlib
-keep class io.github.up9cloud.td.** { *; }
-keepclassmembers class io.github.up9cloud.td.** { *; }

# Media Kit
-keep class com.alexmercerind.mediakit.** { *; }
-keepclassmembers class com.alexmercerind.mediakit.** { *; }

# Preserve JNI signatures
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

-dontwarn com.google.android.play.core.**