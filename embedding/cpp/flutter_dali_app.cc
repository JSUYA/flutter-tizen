// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_dali_app.h"

// Once the DALi application model API is public, link against it directly and
// derive Host from tizen_appfw::DaliApplication; the native window handle is
// then GetDefaultWindow().GetNativeHandle().Get<T>() with the public API only:
// #include <dali/public-api/adaptor-framework/window.h>
// #include <dali/public-api/object/any.h>
// #include <dali_application.h>
// See also the commented USER_LIBS in project_def.prop.
#include "dali_application_abi.h"
#include "tizen_log.h"

// Forwards the callbacks of the DALi application to |FlutterApp|.
class FlutterDaliApp::Host : public DaliApplicationAbi {
 public:
  Host(FlutterDaliApp *app, int argc, char **argv)
      : DaliApplicationAbi(argc, argv), app_(app) {}

 protected:
  bool OnCreate() override {
    if (app_->use_dali_window_) {
      app_->window_handle_ = GetDefaultWindowHandle();
      if (!app_->window_handle_) {
        return false;
      }
    }
    return app_->OnCreate();
  }

  void OnTerminate() override {
    if (app_->IsRunning()) {
      app_->OnTerminate();
    }
  }

  void OnPause() override {
    if (app_->IsRunning()) {
      app_->OnPause();
    }
  }

  void OnResume() override {
    if (app_->IsRunning()) {
      app_->OnResume();
    }
  }

  void OnControl(app_control_h control) override {
    if (app_->IsRunning()) {
      app_->OnAppControlReceived(control);
    }
  }

  void OnLowBattery(app_event_low_battery_status_e status) override {
    if (app_->IsRunning()) {
      app_->OnLowBattery(nullptr);
    }
  }

  void OnLowMemory(app_event_low_memory_status_e status) override {
    if (app_->IsRunning()) {
      app_->OnLowMemory(nullptr);
    }
  }

  void OnLanguageChanged(const std::string &language) override {
    if (app_->IsRunning()) {
      app_->OnLanguageChanged(nullptr);
    }
  }

  void OnDeviceOrientationChanged(
      app_device_orientation_e orientation) override {
    if (app_->IsRunning()) {
      app_->OnDeviceOrientationChanged(nullptr);
    }
  }

  void OnRegionFormatChanged(const std::string &region) override {
    if (app_->IsRunning()) {
      app_->OnRegionFormatChanged(nullptr);
    }
  }

 private:
  FlutterDaliApp *app_;
};

int FlutterDaliApp::Run(int argc, char **argv) {
  if (!DaliApplicationAbi::Load()) {
    TizenLog::Error("The DALi application model is not available.");
    return -1;
  }
  Host host(this, argc, argv);
  int ret = host.Run();
  if (ret != 0) {
    TizenLog::Error("Could not launch an application. (%d)", ret);
  }
  return ret;
}
