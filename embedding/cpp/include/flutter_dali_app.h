// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_DALI_APP_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_DALI_APP_H_

#include "flutter_app.h"

// The app base class for headed Flutter execution hosted by the DALi
// application model (tizen_appfw::DaliApplication) instead of the EFL
// application model (ui_app_main).
//
// The lifecycle callbacks of |FlutterApp| are invoked by the DALi application.
// System event callbacks receive a null |app_event_info_h| because the DALi
// application model delivers the event values directly.
//
// The DALi application model is loaded at runtime, so Run() fails on devices
// that do not provide it.
class FlutterDaliApp : public FlutterApp {
 public:
  // |FlutterApp|
  int Run(int argc, char **argv) override;

 protected:
  // Whether to render into the default window of the DALi application instead
  // of a window created by Flutter.
  //
  // Experimental: the DALi adaptor renders into its default window as well, so
  // both renderers share one surface. If false, the default window stays
  // hidden and Flutter creates its own window as usual.
  bool use_dali_window_ = false;

 private:
  class Host;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_DALI_APP_H_ */
