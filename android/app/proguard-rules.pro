## Proguard rules for StoryLoka

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# local_auth
-keep class io.flutter.plugins.localauth.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# mobile_scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Don't warn on unused referenced classes
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
