# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Tdlib
-keep class org.drinkless.tdlib.** { *; }
-keepclassmembers class org.drinkless.tdlib.** { *; }

# Media Kit
-keep class com.alexmercerind.mediakit.** { *; }
-keepclassmembers class com.alexmercerind.mediakit.** { *; }

# Preserve JNI signatures
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
