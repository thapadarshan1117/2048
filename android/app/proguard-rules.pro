# Flutter and the plugins we use are already consumer-proguard aware; these
# rules only cover reflection used by the Firebase and Ads SDKs, which are
# optional at runtime.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
