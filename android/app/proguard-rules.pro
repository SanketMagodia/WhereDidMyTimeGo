-keepattributes InnerClasses,Signature,AnnotationDefault,EnclosingMethod

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your custom Widget and Service classes
-keep class com.example.timelog.MainActivity { *; }
-keep class com.example.timelog.ScheduleWidgetProvider { *; }
-keep class com.example.timelog.TodoWidgetProvider { *; }
-keep class com.example.timelog.ScheduleWidgetService { *; }
-keep class com.example.timelog.TodoWidgetService { *; }

# Keep home_widget classes
-keep class es.antonborri.home_widget.** { *; }

# Flutter Deferred Components (ignore missing Play Store split-install if not used)
-dontwarn com.google.android.play.core.**

# Keep the generated R classes (for layouts/ids)
-keep class com.example.timelog.R { *; }
-keep class com.example.timelog.R$* { *; }

# MediaPipe & Gemma AI (Critical for release minification)
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.fpl.liquidfun.** { *; }
-dontwarn com.google.fpl.liquidfun.**
-keep class androidx.window.layout.** { *; }
-dontwarn androidx.window.layout.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep everything in flutter_gemma package
-keep class com.google.mediapipe.tasks.genai.** { *; }
-dontwarn com.google.mediapipe.tasks.genai.**
-keep class com.google.mediapipe.proto.** { *; }
-dontwarn com.google.mediapipe.proto.**
-keep class com.google.mediapipe.framework.** { *; }
-dontwarn com.google.mediapipe.framework.**
