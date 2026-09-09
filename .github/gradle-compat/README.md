# Android Gradle compatibility check

Who compiles the Kotlin in `maplibre_gl/android` depends on the host app, not on this repository:

| App configuration | Kotlin compiled by |
|---|---|
| AGP 8 | the Kotlin Gradle Plugin, applied by the module |
| AGP 9, built-in Kotlin enabled (its default) | AGP itself |
| AGP 9, `android.builtInKotlin=false` (what the Flutter template writes from 3.44 on) | KGP again, applied by the module or by Flutter's fallback |

0.27.0 shipped a version of that logic where the third row had nobody compiling its Kotlin, and no
build in this repository noticed, because the example app pins one AGP version (#1008, #1018).

This standalone Gradle build configures the module on its own and asserts which side owns the
compilation, so every combination is covered without an app, a Flutter SDK, or a full build. It is
run by the `android-gradle-compat` job in `.github/workflows/flutter_ci.yml`.

## Running it locally

Needs JDK 21, an Android SDK, and a Gradle matching the AGP under test: AGP 8 wants Gradle 9.5 at
the latest, since Gradle 9.6 removed an internal API it relies on, and AGP 9.4 wants 9.6 or newer.

```sh
cd .github/gradle-compat

# AGP 9 with built-in Kotlin off: the case that broke in 0.27.0
gradle :maplibre_gl:help -PagpVersion=9.0.1 -PkgpVersion=2.3.20 \
    -Pandroid.builtInKotlin=false -Pandroid.newDsl=false -PexpectKotlinOwner=kgp

# AGP 9 as it comes out of the box, compiling Kotlin itself
gradle :maplibre_gl:help -PagpVersion=9.3.1 -PexpectKotlinOwner=agp
```

Leave `-PexpectKotlinOwner` out to print what happens instead of asserting it. Every run reports a
line like `gradle-compat: agp=9.3.1 builtInKotlin=false owner=kgp compileDebugKotlin=true`.
