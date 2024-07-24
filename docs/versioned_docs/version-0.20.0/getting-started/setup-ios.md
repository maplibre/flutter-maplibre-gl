---
sidebar_position: 2
---

# Setup iOS

There is no longer any specific setup needed to include the package on iOS.

## Use the location feature

If you access your users' location, you should also add the following key
to `ios/Runner/Info.plist` to explain why you need access to their location
data:

```xml title="ios/Runner/Info.plist"
<dict>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>[Your explanation here]</string>
</dict>
```

A possible explanation could be: "Shows your location on the map".

## Upgrading from a previous version

Previous versions of the package required you to add the following lines to
your `ios/Podfile`. You'll have to remove these lines from your `ios/Podfile` 
or your project won't build.

<details>
<summary>View obsolete code</summary>

```ruby title="ios/Podfile"
source 'https://cdn.cocoapods.org/'
source 'https://github.com/m0nac0/flutter-maplibre-podspecs.git'

pod 'MapLibre'
pod 'MapLibreAnnotationExtension'
```

</details>
