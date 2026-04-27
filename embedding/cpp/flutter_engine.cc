// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine.h"

#include <flutter_tizen.h>

#include <algorithm>
#include <mutex>

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
    engine_alive_->store(false);
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
    engine_alive_->store(false);
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

// Context passed through the C callback. It is completed only after both the C
// call has returned and the embedder callback has fired, so a future
// synchronous success callback cannot observe a missing view handle.
struct AddViewContext {
  FlutterDesktopEngineRef engine = nullptr;
  FlutterDesktopViewRef view = nullptr;
  std::shared_ptr<std::atomic_bool> engine_alive;
  FlutterEngine::AddViewCallback callback;
  std::mutex mutex;
  bool add_call_returned = false;
  bool callback_fired = false;
  bool dispatched = false;
  bool added = false;
  FlutterDesktopViewId view_id = FLUTTER_DESKTOP_INVALID_VIEW_ID;
};

using AddViewContextPtr = std::shared_ptr<AddViewContext>;

void CompleteAddViewIfReady(const AddViewContextPtr& ctx) {
  FlutterDesktopEngineRef engine = nullptr;
  FlutterDesktopViewRef view_ref = nullptr;
  std::shared_ptr<std::atomic_bool> engine_alive;
  FlutterEngine::AddViewCallback callback;
  bool added = false;
  FlutterDesktopViewId view_id = FLUTTER_DESKTOP_INVALID_VIEW_ID;
  {
    std::lock_guard<std::mutex> lock(ctx->mutex);
    if (!ctx->add_call_returned || !ctx->callback_fired || ctx->dispatched) {
      return;
    }
    ctx->dispatched = true;
    engine = ctx->engine;
    view_ref = ctx->view;
    engine_alive = ctx->engine_alive;
    callback = std::move(ctx->callback);
    added = ctx->added && (view_ref != nullptr);
    view_id = ctx->view_id;
  }

  std::unique_ptr<FlutterView> view;
  if (added) {
    view =
        std::make_unique<FlutterView>(engine, view_ref, view_id, engine_alive);
  }
  if (callback) {
    callback(std::move(view), added);
  }
}

void AddViewTrampoline(bool added, FlutterDesktopViewId view_id,
                       void* user_data) {
  std::unique_ptr<AddViewContextPtr> holder(
      static_cast<AddViewContextPtr*>(user_data));
  AddViewContextPtr ctx = *holder;
  {
    std::lock_guard<std::mutex> lock(ctx->mutex);
    ctx->callback_fired = true;
    ctx->added = added;
    ctx->view_id = view_id;
  }
  CompleteAddViewIfReady(ctx);
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
  auto ctx = std::make_shared<AddViewContext>();
  ctx->engine = engine_;
  ctx->engine_alive = engine_alive_;
  ctx->callback = std::move(callback);
  auto* callback_context = new AddViewContextPtr(ctx);
  FlutterDesktopViewRef view = FlutterDesktopEngineAddView(
      engine_, properties, &AddViewTrampoline, callback_context);
  const bool issued = view != nullptr;
  {
    std::lock_guard<std::mutex> lock(ctx->mutex);
    ctx->view = view;
    ctx->add_call_returned = true;
  }
  CompleteAddViewIfReady(ctx);
  return issued;
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
