-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepattributes JavascriptInterface
-keepattributes *Annotation*

-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}

-optimizations !method/inlining/*

-keepclasseswithmembers class * {
  public void onPayment*(...);
}

-keep class androidx.lifecycle.** { *; }
# Flutter references Play Core for deferred components. This app does not use
# them, so the classes are absent and R8 fails the build on the dangling refs.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Plugin entry points are found reflectively by the generated registrant.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
