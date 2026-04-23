# Multi-view on flutter-tizen

Multi-view lets a single Flutter engine drive more than one Tizen window in
the same process. The implicit window that the Tizen app framework creates
on startup continues to work as before (view id 0). Additional windows can
be added and removed at runtime through both C++ and Dart APIs.

> **Status (2026-04):** platform-side infrastructure has landed (engine
> registry, `FlutterEngineAddView`/`FlutterEngineRemoveView` wiring, shared
> EGL display and share-group contexts, public C API, `flutter_tizen/multi_view`
> platform channel, `FlutterView` C++ wrapper, `TizenMultiView` Dart helper).
> Secondary views are **registered** with the Flutter framework so
> `PlatformDispatcher.views` reports them, but they are **not yet rendered**:
> the Tizen renderer config still routes every draw to the implicit view.
> Rendering of secondary views requires a `FlutterCompositor` with a
> `present_view_callback` and per-view backing stores, which is tracked as a
> follow-up change on top of this foundation.

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

- The `AddViewCallback` is invoked asynchronously on the platform thread once
  `FlutterEngineAddView` has acknowledged the new view.
- The returned `std::unique_ptr<FlutterView>` owns the view handle; keep it
  alive as long as the window should exist. Destroying it calls
  `FlutterDesktopEngineRemoveView`, which is also async but fire-and-forget
  at the C++ wrapper level.
- The implicit view is managed by `FlutterApp` itself and cannot be added or
  removed through this API.

## Using multi-view from Dart

The `flutter_tizen` package exposes `TizenMultiView` in Dart:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_tizen/flutter_tizen.dart';

Future<void> openPip() async {
  final handle = await TizenMultiView.addView(
    width: 400,
    height: 300,
    topLevel: true,
  );

  final view = PlatformDispatcher.instance.views.firstWhere(
    (FlutterView v) => v.viewId == handle.viewId,
  );

  runWidget(
    View(view: view, child: const PipOverlay()),
  );
}

Future<void> closePip(int viewId) async {
  await TizenMultiView.removeView(viewId);
}
```

Each secondary view can host an independent widget tree by pairing
`runWidget` with a `View(view: ...)` root. The implicit view (id 0)
continues to work with the usual `runApp`.

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
- **NUI path (`FlutterDesktopViewCreateFromImageView`) stays single-view.**
  The DALi `ImageView` container is a single render target by design; a
  separate design is required before enabling multi-view in that path.
- **Accessibility anchors to the implicit view.** Tizen's accessibility API
  exposes one app-level tree, so secondary views share the same root.
- **Plugin ecosystem awareness.** Most flutter-tizen plugins predate
  multi-view and do not thread `viewId` through their platform channels.
  Plugins that expose `PlatformView`s to a specific view need a follow-up to
  carry the view id in their arguments.
