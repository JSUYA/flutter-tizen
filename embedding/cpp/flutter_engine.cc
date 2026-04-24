// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine.h"

#include <flutter_tizen.h>

#include <algorithm>

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  return FlutterEngine::Create("../res/flutter_assets", "../res/icudtl.dat",
                               "../lib/libapp.so", dart_entrypoint,
                               dart_entrypoint_args);
}

std::unique_ptr<FlutterEngine> FlutterEngine::Create(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  FlutterEngine* engine =
      new FlutterEngine(assets_path, icu_data_path, aot_library_path,
                        dart_entrypoint, dart_entrypoint_args);
  if (engine->engine_) {
    return std::unique_ptr<FlutterEngine>(engine);
  } else {
    delete engine;
    return nullptr;
  }
}

FlutterEngine::FlutterEngine(
    const std::string& assets_path, const std::string& icu_data_path,
    const std::string& aot_library_path, const std::string& dart_entrypoint,
    const std::vector<std::string>& dart_entrypoint_args) {
  engine_arguments_ = std::make_unique<FlutterEngineArguments>();

  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = assets_path.c_str();
  engine_prop.icu_data_path = icu_data_path.c_str();
  engine_prop.aot_library_path = aot_library_path.c_str();

  const std::vector<std::string>& engine_args =
      engine_arguments_->GetArguments();
  std::vector<const char*> switches;
  for (const std::string& arg : engine_args) {
    switches.push_back(arg.c_str());
  }
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();

  engine_prop.entrypoint =
      dart_entrypoint.empty() ? nullptr : dart_entrypoint.c_str();

  std::vector<const char*> entrypoint_args;
  for (const std::string& arg : dart_entrypoint_args) {
    entrypoint_args.push_back(arg.c_str());
  }

  engine_prop.dart_entrypoint_argc = entrypoint_args.size();
  engine_prop.dart_entrypoint_argv = entrypoint_args.data();
  engine_prop.ui_thread_policy =
      FlutterDesktopUIThreadPolicy::kRunOnSeparateThread;

  engine_ = FlutterDesktopEngineCreate(engine_prop);
}

FlutterEngine::~FlutterEngine() {
  if (engine_alive_) {
    *engine_alive_ = false;
  }
  if (owns_engine_) {
    Shutdown();
  }
}

bool FlutterEngine::Run() {
  if (engine_) {
    return FlutterDesktopEngineRun(engine_);
  }
  return false;
}

void FlutterEngine::Shutdown() {
  if (engine_alive_) {
    *engine_alive_ = false;
  }
  if (engine_) {
    FlutterDesktopEngineShutdown(engine_);
    engine_ = nullptr;
  }
}

void FlutterEngine::NotifyAppIsResumed() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsResumed(engine_);
  }
}

void FlutterEngine::NotifyAppIsPaused() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsPaused(engine_);
  }
}

void FlutterEngine::NotifyAppIsDetached() {
  if (engine_) {
    FlutterDesktopEngineNotifyAppIsDetached(engine_);
  }
}

void FlutterEngine::NotifyAppControl(app_control_h app_control) {
  if (engine_) {
    FlutterDesktopEngineNotifyAppControl(engine_, app_control);
  }
}

void FlutterEngine::NotifyLowMemoryWarning() {
  if (engine_) {
    FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
  }
}

void FlutterEngine::NotifyLocaleChange() {
  if (engine_) {
    FlutterDesktopEngineNotifyLocaleChange(engine_);
  }
}

FlutterDesktopEngineRef FlutterEngine::RelinquishEngine() {
  owns_engine_ = false;
  return engine_;
}

namespace {

// Context passed through the C callback. Owns a heap copy of the user's
// std::function so it can outlive |AddView|'s stack frame. The trampoline
// below is the sole owner of this object and always deletes it; callers of
// |FlutterDesktopEngineAddView| must not delete |ctx| themselves, even on
// synchronous failure, because the C API guarantees the callback fires
// exactly once.
struct AddViewContext {
  FlutterDesktopEngineRef engine;
  FlutterDesktopViewRef view;  // Lazily populated; may still be null when the
                                // trampoline fires after a synchronous failure.
  std::shared_ptr<bool> engine_alive;
  FlutterEngine::AddViewCallback callback;
};

void AddViewTrampoline(bool added, FlutterDesktopViewId view_id,
                       void* user_data) {
  auto* ctx = static_cast<AddViewContext*>(user_data);
  std::unique_ptr<FlutterView> view;
  if (added && ctx->view) {
    view = std::make_unique<FlutterView>(ctx->engine, ctx->view, view_id,
                                         ctx->engine_alive);
  }
  if (ctx->callback) {
    ctx->callback(std::move(view), added);
  }
  delete ctx;
}

}  // namespace

bool FlutterEngine::AddView(const FlutterDesktopWindowProperties& properties,
                            AddViewCallback callback) {
  if (!engine_) {
    // The engine is not running, so |FlutterDesktopEngineAddView| cannot be
    // issued. We haven't allocated a context yet, so invoke the user
    // callback here with added=false to preserve the "callback fires
    // exactly once" contract.
    if (callback) {
      callback(nullptr, false);
    }
    return false;
  }
  auto* ctx =
      new AddViewContext{engine_, nullptr, engine_alive_, std::move(callback)};
  FlutterDesktopViewRef view = FlutterDesktopEngineAddView(
      engine_, properties, &AddViewTrampoline, ctx);
  // |FlutterDesktopEngineAddView|'s contract is that it always invokes our
  // |AddViewTrampoline| (even on early/synchronous failure), which deletes
  // |ctx|. Do NOT delete |ctx| here: doing so was a double-free on the
  // sync-failure path.
  if (!view) {
    return false;
  }
  ctx->view = view;
  return true;
}

bool FlutterEngine::RemoveView(FlutterDesktopViewId view_id) {
  if (!engine_) {
    return false;
  }
  return FlutterDesktopEngineRemoveView(engine_, view_id, nullptr, nullptr);
}

FlutterDesktopPluginRegistrarRef FlutterEngine::GetRegistrarForPlugin(
    const std::string& plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
