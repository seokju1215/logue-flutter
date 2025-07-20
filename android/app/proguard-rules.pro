# ----------------------------
# ✅ Flutter core
# ----------------------------
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.app.** { *; }
-dontwarn io.flutter.app.**

# ----------------------------
# ✅ Flutter plugins
# ----------------------------
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# --- Enum 클래스는 반드시 values() 메서드를 유지해야 함 ---
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ----------------------------
# ✅ Firebase
# ----------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ----------------------------
# ✅ Google Play Services (Google 로그인 등)
# ----------------------------
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ----------------------------
# ✅ Supabase SDK
# ----------------------------
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

-keep class io.supabase.flutter.** { *; }
-dontwarn io.supabase.flutter.**

-keep class com.supabase.** { *; }
-dontwarn com.supabase.**

# kotlinx.serialization (used internally by Supabase)
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**

# kotlinx.coroutines (used by Supabase/ktor)
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ktor client (used by Supabase)
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# ktor logging (optional)
-keep class io.ktor.client.plugins.logging.** { *; }
-dontwarn io.ktor.client.plugins.logging.**

# ----------------------------
# ✅ Kotlin (reflection 이슈 방지)
# ----------------------------
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# ----------------------------
# ✅ Compose (사용 중인 경우)
# ----------------------------
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# ----------------------------
# ✅ WindowManager (멀티 윈도우 관련 Jetpack)
# ----------------------------
-keep class androidx.window.** { *; }
-dontwarn androidx.window.**

# ----------------------------
# ✅ Flutter entry points
# ----------------------------
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }

# ----------------------------
# ✅ Amplitude (사용 중인 경우)
# ----------------------------
-keep class com.amplitude.** { *; }
-dontwarn com.amplitude.**

# ----------------------------
# ✅ Gson / org.json (혹시 내부에서 사용 시)
# ----------------------------
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

-keep class org.json.** { *; }
-dontwarn org.json.**

# ----------------------------
# ✅ 로그 제거 (릴리즈 빌드 최적화용)
# ----------------------------
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ----------------------------
# ✅ 내 앱의 코드가 난독화되면서 reflection 문제 방지
# ----------------------------
-keep class dev.seokju.logue.** { *; }
-dontwarn dev.seokju.logue.**