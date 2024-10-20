---
sidebar_position: 3
---

# Setup Android

## Use a compatible Kotlin version

Ensure that you are using Kotlin version
**1.9.0** or newer. You can check the most recent Kotlin version on
[kotlinlang.org](https://kotlinlang.org/docs/releases.html#release-details).

#### (new) Gradle with a declarative plugins block

Open `android/settings.gradle` and set the Kotlin version like this:

```gradle title="android/settings.gradle"
plugins {
    // ...
    id "org.jetbrains.kotlin.android" version "1.9.0" apply false
}
```

In case you can't find the `plugins {}` block your app still uses the old apply
script method.

#### (old) In a legacy apply script gradle file:

Open `android/app/build.gradle` and set the Kotlin version like this:

```gradle title="android/app/build.gradle"
buildscript {
    ext.kotlin_version = '1.9.0'
    // ...
}
```

## Minimum SDK version

If you are using a flutter version below 3.22, you need to set the minimum SDK
version to 21 or higher in `android/app/build.gradle`.

```gradle title="android/app/build.gradle"
    defaultConfig {
        minSdk = 21 // previously flutter.minSdkVersion
        // ...
    }
```

If you are using the old apply script method in gradle, `minSdk` is named
`minSdkVersion`.

Starting from flutter 3.22, the minimum SDK version is set to 21 by default
and you can keep `flutter.minSdkVersion`.

## Use the location feature

If you want to show the user's location on the map you need to add
the `ACCESS_COARSE_LOCATION` or `ACCESS_FINE_LOCATION` permission in the
application manifest `android/app/src/main/AndroidManifest.xml`.

```xml title="android/app/src/main/AndroidManifest.xml"

<manifest>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
</manifest>
```

Starting from Android API level 23 you also need to request it at runtime. This
plugin does not handle this for you. Our example app uses the
[flutter plugin "location"](https://pub.dev/packages/location) for this.
