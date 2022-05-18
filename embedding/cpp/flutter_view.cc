// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_view.h"

#include <cassert>
#include <cerrno>
#include <fstream>

#include "tizen_log.h"
#include "utils.h"

bool FlutterView::OnCreate() {
  TizenLog::Debug("Launching a Flutter application...");

  FlutterDesktopViewProperties view_prop = {};
  view_prop.x = window_offset_x_;
  view_prop.y = window_offset_y_;
  view_prop.width = window_width_;
  view_prop.height = window_height_;

  // Read engine arguments passed from the tool.
  Utils::ParseEngineArgs(&engine_args_);

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

  engine_ = FlutterDesktopEngineCreate(engine_prop);
  if (!engine_) {
    TizenLog::Error("Could not create a Flutter engine.");
    return false;
  }
  view_ = FlutterDesktopViewCreateFromNewView(view_prop, engine_, nullptr);
  if (!view_) {
    TizenLog::Error("Could not launch a Flutter application.");
    return false;
  }
  return true;
}

void FlutterView::OnResume() {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppIsResumed(engine_);
}

void FlutterView::OnPause() {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppIsPaused(engine_);
}

void FlutterView::OnTerminate() {
  assert(IsRunning());

  TizenLog::Debug("Shutting down the application...");

  FlutterDesktopEngineShutdown(engine_);
  engine_ = nullptr;
}

void FlutterView::OnAppControlReceived(app_control_h app_control) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyAppControl(engine_, app_control);
}

void FlutterView::OnLowMemory(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLowMemoryWarning(engine_);
}

void FlutterView::OnLanguageChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

void FlutterView::OnRegionFormatChanged(app_event_info_h event_info) {
  assert(IsRunning());

  FlutterDesktopEngineNotifyLocaleChange(engine_);
}

int FlutterView::Run(int argc, char **argv) {
  //Only Engine Run
  return false;
}

FlutterDesktopPluginRegistrarRef FlutterView::GetRegistrarForPlugin(
    const std::string &plugin_name) {
  if (engine_) {
    return FlutterDesktopEngineGetPluginRegistrar(engine_, plugin_name.c_str());
  }
  return nullptr;
}
