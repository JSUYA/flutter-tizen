// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_DALI_APPLICATION_ABI_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_DALI_APPLICATION_ABI_H_

#include <app_common.h>
#include <app_control.h>

#include <string>

// ABI mirror of tizen_appfw::DaliApplication declared in <dali_application.h>
// (dali-application 1.0.1, libdali-application.so.1).
//
// The DALi application model is not part of the public SDK yet, so the
// embedding cannot include its header or link against its library. Instead the
// library is loaded with dlopen at runtime and the non-virtual members below
// forward to its exported symbols. The object layout (vptr followed by one
// pointer-sized pimpl slot) and the order of the virtual functions must match
// the real class exactly: the library invokes the lifecycle callbacks through
// the vtable of the derived class.
//
// Only public API is mirrored: <dali_application.h>,
// <dali/public-api/adaptor-framework/window.h> (Window::GetNativeHandle), and
// <dali/public-api/object/any.h> (Any::GetType). No internal or devel-api
// headers are involved.
//
// Once the API is public, replace this class with tizen_appfw::DaliApplication:
// delete dali_application_abi.{h,cc}, enable the includes commented out in
// flutter_dali_app.cc, and add the libraries to project_def.prop.
class DaliApplicationAbi {
 public:
  // Loads libdali-application.so.1 and resolves the symbols used by this class.
  //
  // Returns false if the DALi application model is not available on the device.
  static bool Load();

  DaliApplicationAbi(int argc, char **argv);
  virtual ~DaliApplicationAbi();

  DaliApplicationAbi(const DaliApplicationAbi &) = delete;
  DaliApplicationAbi &operator=(const DaliApplicationAbi &) = delete;

  // Runs the main loop of the app until Exit() is called.
  //
  // Returns 0 on success, or a negative value if the app could not be started.
  int Run();

  // Exits the main loop. OnTerminate() is called before the loop exits.
  void Exit();

  // Returns the native window handle (Ecore_Wl2_Window* or
  // tizen_core_wl_window_h, depending on the windowing backend of the DALi
  // adaptor on the device) of the default window, or nullptr on failure.
  //
  // Only valid after OnCreate() has been called.
  void *GetDefaultWindowHandle() const;

 protected:
  // The order of these functions is part of the ABI.
  virtual bool OnCreate() = 0;
  virtual void OnTerminate() {}
  virtual void OnPause() {}
  virtual void OnResume() {}
  virtual void OnControl(app_control_h control) {}
  virtual void OnLowBattery(app_event_low_battery_status_e status) {}
  virtual void OnLowMemory(app_event_low_memory_status_e status) {}
  virtual void OnLanguageChanged(const std::string &language) {}
  virtual void OnDeviceOrientationChanged(app_device_orientation_e orientation) {
  }
  virtual void OnRegionFormatChanged(const std::string &region) {}
  virtual void OnSuspendedStateChanged(app_suspended_state_e state) {}
  virtual void OnTimeZoneChanged(const std::string &time_zone,
                                 const std::string &time_zone_id) {}

 private:
  // std::unique_ptr<Impl> in the real class. Created by the constructor and
  // destroyed by the destructor of the library.
  void *impl_ = nullptr;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_DALI_APPLICATION_ABI_H_ */
