# Defensive JNI/Pigeon interop rules for Android release builds.
# Flutter shared_preferences_android 2.5.0 uses native JNI method signatures;
# R8 must not rename Kotlin coroutine classes referenced by the JNI bridge.
# The plugin is also pinned to the known method-channel version in pubspec.yaml.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
