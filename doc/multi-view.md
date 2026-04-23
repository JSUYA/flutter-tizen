# Multi-view on flutter-tizen

Multi-view lets a single Flutter engine drive more than one Tizen window in
the same process. The implicit window that the Tizen app framework creates
on startup continues to work as before (view id 0). Additional windows can
be added and removed at runtime through both C++ and Dart APIs.

> **Status (2026-04):** platform-side infrastructure has landed (engine
> registry, `FlutterEngineAddView`/`FlutterEngineRemoveView` wiring, shared
> EGL display and share-group contexts, public C API, `flutter_tizen/multi_view`
> platform channel, `FlutterView` C++ wrapper, `TizenMultiView` Dart helper).
>
> **Secondary views do NOT render yet.** They are registered with the
> Flutter framework so `PlatformDispatcher.views` reports them and pointer
> events carry the correct `view_id`, but the Tizen renderer config still
> sends every draw to the implicit view's surface. Calling
> `runWidget(View(view: secondaryView))` will build a widget tree and
> schedule frames, but no pixels reach the secondary window. Rendering
> requires a `FlutterCompositor` with a `present_view_callback` and
> per-view backing stores, which is tracked as a follow-up on top of this
> foundation.
>
> **Secondary views share the engine's platform channels.** Channels like
> `flutter/textinput`, `flutter/platform`, `flutter/window`, and
> `flutter/mousecursor` are registered once at the engine level and always
> route to the implicit view. Text input, clipboard, and similar features
> therefore only work on the implicit view today.

## Why multi-view?

Typical Tizen scenarios that benefit from multi-view:

- **Picture-in-picture (TV)** — overlay a small video player window while the
  main UI continues to run.
- **Secondary display (IoT / Raspberry Pi)** — drive an auxiliary display
  without launching a second process.
- **Top-level system overlays** — notification popups, quick-settings panels
  rendered by the same app as the host UI.

All of these share one Dart isolate, one engine, and therefore one state and
one navigator tree unless the app intentionally splits them with
[`runWidget`](https://api.flutter.dev/flutter/widgets/runWidget.html).

## Architecture overview

```
FlutterApp (C++ wrapper in flutter-tizen)
│
├── FlutterEngine (C++ wrapper)
│       ⇅ public C API: flutter_tizen.h
├──[implicit view 0] FlutterTizenView (embedder)
│     ├── TizenWindowEcoreWl2 ──▶ Ecore_Wl2_Window + EGL/Vulkan surface
│     └── TizenRendererEgl / TizenRendererVulkan
│
└── [view 1, 2, ...] additional FlutterTizenView (engine non-owning)
      ├── TizenWindowEcoreWl2 (shares EcoreWl2Context singleton)
      └── TizenRendererEgl (shares TizenEglDisplay + share_context)
```

The embedder introduces two process-wide singletons that make multi-view
possible:

- **`EcoreWl2Context`** — holds the single `ecore_wl2_init()` /
  `ecore_wl2_display_connect()` pair. All windows share one Wayland display.
- **`TizenEglDisplay`** — holds the single `eglInitialize()` and the chosen
  EGLConfig. Renderers share the display and pass the implicit view's
  onscreen context as the share-group root so GLES textures and shaders are
  reusable across views.

## Using multi-view from C++

`FlutterApp` gains an `OnImplicitViewReady()` hook that fires immediately
after the implicit view has been created. Subclasses can call
`FlutterApp::AddView` from that hook (or any later point) to register
additional top-level windows.

```cpp
#include <flutter_app.h>
#include <flutter_view.h>

class App : public FlutterApp {
 public:
  void OnImplicitViewReady() override {
    FlutterDesktopWindowProperties props = {};
    props.width = 400;
    props.height = 300;
    props.top_level = true;
    props.renderer_type = kEGL;

    AddView(props, [](std::unique_ptr<FlutterView> view, bool added) {
      if (added) {
        dlog_print(DLOG_INFO, "Flutter",
                   "Secondary view id=%lld is ready",
                   static_cast<long long>(view->GetId()));
        // Dropping |view| later triggers an async RemoveView on the engine.
      }
    });
  }
};

int main(int argc, char* argv[]) {
  App app;
  return app.Run(argc, argv);
}
```

Notes:

- The `AddViewCallback` is invoked once `FlutterEngineAddView` has
  acknowledged the new view.
- The returned `std::unique_ptr<FlutterView>` owns the view handle; keep it
  alive as long as the window should exist. Destroying it calls
  `FlutterDesktopEngineRemoveView`, which is also async but fire-and-forget
  at the C++ wrapper level.
- The implicit view is managed by `FlutterApp` itself and cannot be added or
  removed through this API.

## Using multi-view from Dart

The `flutter_tizen` package exposes `TizenMultiView` in Dart. Today the
helper is most useful for exercising the framework-side multi-view code
paths and for verifying that input events carry the correct `view_id`:

```dart
import 'package:flutter_tizen/flutter_tizen.dart';

Future<int> registerPip() async {
  final handle = await TizenMultiView.addView(
    width: 400,
    height: 300,
    topLevel: true,
  );
  // handle.viewId now appears in PlatformDispatcher.instance.views.
  // WARNING: rendering a widget tree into this view is not supported
  // yet; see the Status note at the top of this doc.
  return handle.viewId;
}

Future<void> closePip(int viewId) async {
  await TizenMultiView.removeView(viewId);
}
```

Once the FlutterCompositor follow-up lands, users will be able to pair
`PlatformDispatcher.view(id:)` with `runWidget(View(view: ...))` to mount
an independent widget tree inside each secondary window. The implicit
view (id 0) continues to work with the usual `runApp`.

## Manifest considerations

- Setting `topLevel: true` (or `is_top_level_ = true` in C++) requires the
  `http://tizen.org/privilege/window.priority.set` privilege declared in
  `tizen-manifest.xml`.
- Add `enable_multi_view` metadata if your app opts into multi-view-specific
  behaviour gated by the embedder (reserved for future work):

  ```xml
  <metadata key="http://tizen.org/metadata/flutter_tizen/enable_multi_view"
            value="true"/>
  ```

## Known limitations

- **Rendering of secondary views is not yet wired up.** The platform side
  registers every view with Flutter, input routing is per-view (via
  `FlutterPointerEvent.view_id`), and the `PlatformDispatcher.views`
  collection reports every view correctly, but only the implicit view paints
  to its surface today. The follow-up work adds a `FlutterCompositor` that
  uses `present_view_callback` and creates one backing store per view.
- **Platform channels are shared across views.** `flutter/textinput`,
  `flutter/window`, `flutter/platform`, `flutter/mousecursor`, and
  `flutter/platform_views` are registered once at the engine level and
  always target the implicit view. Features layered on those channels
  (text input, clipboard, cursor changes, platform view embedding, app
  window manipulation) therefore only work on the implicit view until a
  future change threads `viewId` through the channel payloads.
- **External textures are anchored to the implicit view's renderer.**
  `FlutterDesktopTextureRegistrar` uses the engine-level renderer accessor,
  which resolves to the implicit view's renderer. Creating external
  textures from a secondary view is not supported.
- **NUI path (`FlutterDesktopViewCreateFromImageView`) stays single-view.**
  The DALi `ImageView` container is a single render target by design; a
  separate design is required before enabling multi-view in that path.
- **Accessibility anchors to the implicit view.** Tizen's accessibility API
  exposes one app-level tree, so secondary views share the same root.
- **Plugin ecosystem awareness.** Most flutter-tizen plugins predate
  multi-view and do not thread `viewId` through their platform channels.
  Plugins that expose `PlatformView`s to a specific view need a follow-up to
  carry the view id in their arguments.
- **Mixing Impeller and Skia EGL configs is rejected.** `TizenEglDisplay`
  is a process-wide singleton and caches the first caller's
  `enable_impeller` flag. Subsequent `Acquire()` calls with a different
  flag return nullptr instead of silently handing back a mismatched
  config.
