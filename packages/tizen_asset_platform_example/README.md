# Tizen asset platform example

This example shows how to mark assets as Tizen-specific with Flutter-Tizen.

```yaml
flutter:
  assets:
    - assets/common.txt
    - path: assets/tizen_only.txt
      platforms:
        - tizen
    - path: assets/android_only.txt
      platforms:
        - android
```

When this app is built with `flutter-tizen build tpk`, the common and Tizen
assets are bundled. The Android-only asset is filtered out of the Tizen bundle.
