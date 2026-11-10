# Reglas de R8 para Chess Master AI

# --- Stockfish: puente JNI, los nombres nativos no se pueden ofuscar ---
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.ibnux.** { *; }
-keep class **.Stockfish { *; }

# --- RevenueCat / facturacion ---
-keep class com.revenuecat.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.revenuecat.**

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Conserva anotaciones y firmas genericas (las usan los plugins) ---
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
