// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_

#include <app_control.h>
#include <flutter/plugin_registry.h>
#include <flutter_tizen.h>

#include <algorithm>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "flutter_engine_arguments.h"
#include "flutter_view.h"

// The engine for Flutter execution.
class FlutterEngine : public flutter::PluginRegistry {
 public:
  virtual ~FlutterEngine();

  // Creates a |FlutterEngine| with an optional entrypoint name and entrypoint
  // arguments.
  static std::unique_ptr<FlutterEngine> Create(
      const std::string& dart_entrypoint = "",
      const std::vector<std::string>& dart_entrypoint_args = {});

  // Creates a |FlutterEngine| with the given arguments.
  static std::unique_ptr<FlutterEngine> Create(
      const std::string& assets_path, const std::string& icu_data_path,
      const std::string& aot_library_path,
      const std::string& dart_entrypoint = "",
      const std::vector<std::string>& dart_entrypoint_args = {});

  // Prevent copying.
  FlutterEngine(FlutterEngine const&) = delete;
  FlutterEngine& operator=(FlutterEngine const&) = delete;

  // Starts running the engine.
  bool Run();

  // Terminates the running engine.
  void Shutdown();

  // Notifies that the host app is visible and responding to user input.
  //
  // This method notifies the running Flutter app that it is "resumed" as per
  // the Flutter app lifecycle.
  void NotifyAppIsResumed();

  // Notifies that the host app is invisible and not responding to user input.
  //
  // This method notifies the running Flutter app that it is "paused" as per
  // the Flutter app lifecycle.
  void NotifyAppIsPaused();

  // Notifies that the engine is detached from any host views.
  //
  // This method notifies the running Flutter app that it is "detached" as per
  // the Flutter app lifecycle.
  void NotifyAppIsDetached();

  // Notifies that the host app received an app control.
  //
  // This method sends the app control to Flutter over the "app control event
  // channel".
  void NotifyAppControl(app_control_h app_control);

  // Notifies that a low memory warning has been received.
  //
  // This method sends a "memory pressure warning" message to Flutter over the
  // "system channel".
  void NotifyLowMemoryWarning();

  // Notifies that the system locale has changed.
  //
  // This method sends a "locale change" message to Flutter.
  void NotifyLocaleChange();

  // Gives up ownership of |engine_|, but keeps a weak reference to it.
  FlutterDesktopEngineRef RelinquishEngine();

  // Async completion callback for |AddView|. On success |view| is the newly
  // registered secondary view and |added| is true; on failure |view| is
  // null.
  using AddViewCallback =
      std::function<void(std::unique_ptr<FlutterView> view, bool added)>;

  // Adds a new secondary view to the running engine.
  //
  // Requires that the implicit view has been created (i.e. the engine is
  // running). |callback| is invoked once the Flutter engine has acknowledged
  // the new view. Returns false synchronously if
  // the request could not be issued at all (engine not running, window
  // creation failed, etc.); |callback| is still invoked with |added| false.
  //
  // NOTE: Until the multi-view compositor work lands, secondary views are
  // registered with the framework (PlatformDispatcher.views reflects them)
  // but their contents are not rendered.
  bool AddView(const FlutterDesktopWindowProperties& properties,
               AddViewCallback callback = {});

  // Removes a secondary view previously created by |AddView|. The implicit
  // view cannot be removed through this API.
  bool RemoveView(FlutterDesktopViewId view_id);

  // |flutter::PluginRegistry|
  FlutterDesktopPluginRegistrarRef GetRegistrarForPlugin(
      const std::string& plugin_name) override;

  // The engine arguments instance containing parsed arguments and metadata
  // flags.
  const FlutterEngineArguments& GetArguments() const {
    return *engine_arguments_;
  }

 private:
  FlutterEngine(const std::string& assets_path,
                const std::string& icu_data_path,
                const std::string& aot_library_path,
                const std::string& dart_entrypoint,
                const std::vector<std::string>& dart_entrypoint_args);

  // Handle for interacting with the C API's engine reference.
  FlutterDesktopEngineRef engine_ = nullptr;

  // Whether or not this wrapper owns |engine_|.
  bool owns_engine_ = true;

  // The engine arguments instance.
  std::unique_ptr<FlutterEngineArguments> engine_arguments_;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_H_ */
