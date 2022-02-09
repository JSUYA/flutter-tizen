// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_view.h"

#include <cassert>
#include <cerrno>
#include <fstream>

#include "tizen_log.h"

bool FlutterView::RunEngine() {
  TizenLog::Debug("Launching a Flutter application...");

  FlutterDesktopWindowProperties window_prop = {};
  window_prop.headed = is_headed_;
  window_prop.x = window_offset_x_;
  window_prop.y = window_offset_y_;
  window_prop.width = window_width_;
  window_prop.height = window_height_;
  window_prop.transparent = is_window_transparent_;
  window_prop.focusable = is_window_focusable_;
  window_prop.top_level = is_top_level_;

  window_prop.parent_elm_window = parent_;

  // Read engine arguments passed from the tool.
  ParseEngineArgs();

  std::vector<const char *> switches;
  for (auto &arg : engine_args_) {
    switches.push_back(arg.c_str());
  }
  std::vector<const char *> entrypoint_args;
  for (auto &arg : dart_entrypoint_args_) {
    entrypoint_args.push_back(arg.c_str());
  }

  FlutterDesktopEngineProperties engine_prop = {};
  engine_prop.assets_path = "../res/flutter_assets";
  engine_prop.icu_data_path = "../res/icudtl.dat";
  engine_prop.aot_library_path = "../lib/libapp.so";
  engine_prop.switches = switches.data();
  engine_prop.switches_count = switches.size();
  engine_prop.entrypoint = dart_entrypoint_.c_str();
  engine_prop.dart_entrypoint_argc = entrypoint_args.size();
  engine_prop.dart_entrypoint_argv = entrypoint_args.data();

  handle_ = FlutterDesktopRunEngine(window_prop, engine_prop);
  if (!handle_) {
    TizenLog::Error("Could not launch a Flutter application.");
    return false;
  }

  return true;
}
/*
void FlutterView::OnResume() {
  assert(IsRunning());

  FlutterDesktopNotifyAppIsResumed(handle_);
}

void FlutterView::OnPause() {
  assert(IsRunning());

  FlutterDesktopNotifyAppIsPaused(handle_);
}

void FlutterView::OnTerminate() {
  assert(IsRunning());

  TizenLog::Debug("Shutting down the application...");

  FlutterDesktopShutdownEngine(handle_);
  handle_ = nullptr;
}

void FlutterView::OnAppControlReceived(app_control_h app_control) {
  assert(IsRunning());

  FlutterDesktopNotifyAppControl(handle_, app_control);
}

void FlutterView::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLowMemoryWarning(handle_);
}

void FlutterView::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLocaleChange(handle_);
}

void FlutterView::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopNotifyLocaleChange(handle_);
}

*/

FlutterDesktopPluginRegistrarRef FlutterView::GetRegistrarForPlugin(
    const std::string &plugin_name) {
  if (handle_) {
    return FlutterDesktopGetPluginRegistrar(handle_, plugin_name.c_str());
  }
  return nullptr;
}

void *FlutterView::GetImageHandle() {
  if (!IsRunning()) {
    return nullptr;
  }
  FlutterDesktopPluginRegistrarRef registrar = FlutterDesktopGetPluginRegistrar(handle_, nullptr);
  return FlutterDesktopGetImageHandle(registrar);
}

void FlutterView::ParseEngineArgs() {
  char *app_id;
  if (app_get_id(&app_id) != 0) {
    TizenLog::Warn("App id is not found.");
    return;
  }
  std::string temp_path("/home/owner/share/tmp/sdk_tools/" +
                        std::string(app_id) + ".rpm");
  free(app_id);

  auto file = fopen(temp_path.c_str(), "r");
  if (!file) {
    return;
  }
  char *line = nullptr;
  size_t len = 0;

  while (getline(&line, &len, file) > 0) {
    if (line[strlen(line) - 1] == '\n') {
      line[strlen(line) - 1] = 0;
    }
    TizenLog::Info("Enabled: %s", line);
    engine_args_.push_back(line);
  }
  free(line);
  fclose(file);

  if (remove(temp_path.c_str()) != 0) {
    TizenLog::Warn("Error removing file: %s", strerror(errno));
  }
}
