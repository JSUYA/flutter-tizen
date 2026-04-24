# multi_view_sample

Interactive Tizen multi-view sample.

This sample exercises the `flutter_tizen` multi-view API with a visual control
surface. It can create several secondary Tizen views with different sizes,
positions, transparency settings, and pixel ratios, then remove, duplicate,
resize, and move them. Move and resize operations recreate the native secondary
view because the current API exposes add/remove primitives rather than an
in-place geometry update call.

By default the app attaches real Flutter widget trees to secondary
`FlutterView`s. The content set covers dashboard and chart widgets, network
video through `video_player_tizen`, a WebView through
`webview_flutter_tizen`, network Lottie animation, interactive Material
controls, semantics-covered controls, a network image, transparent overlays, and
small high-DPI panels.

The stage draws only non-interactive outlines for secondary views. The native
secondary windows are raised above the primary app window so pointer and scroll
events go to the content inside each `FlutterView`.

Secondary widget rendering can be disabled when isolating native view lifecycle
behavior:

```sh
flutter-tizen -d emulator-26111 run --debug \
  --dart-define=MULTI_VIEW_SAMPLE_RENDER_SECONDARY_WIDGETS=false
```

## Run

```sh
flutter-tizen -d emulator-26111 run --debug
```

## Automated scenario

The app includes an emulator-friendly scenario that creates a showcase, moves
and resizes views, duplicates one view, repeatedly adds and removes temporary
views, then clears everything and exits. The log lines are prefixed with
`MULTIVIEW_SAMPLE_TEST`.

```sh
flutter-tizen -d emulator-26111 run --debug \
  --dart-define=MULTI_VIEW_SAMPLE_AUTORUN=true
```
