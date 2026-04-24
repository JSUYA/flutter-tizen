# multi_view_sample

Interactive Tizen multi-view sample.

This sample exercises the `flutter_tizen` multi-view API with a visual control
surface. It can create several secondary Tizen views with different sizes,
positions, transparency settings, and pixel ratios, then remove, duplicate,
resize, and move them. Move and resize operations recreate the native secondary
view because the current API exposes add/remove primitives rather than an
in-place geometry update call.

By default the app does not attach Flutter widget trees to secondary
`FlutterView`s. The current Tizen embedder registers secondary views with the
framework, but secondary view contents require a compositor that presents layers
by view id. Rendering experimental secondary widgets can be enabled explicitly
for compositor work:

```sh
flutter-tizen -d emulator-26111 run --debug \
  --dart-define=MULTI_VIEW_SAMPLE_RENDER_SECONDARY_WIDGETS=true
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
