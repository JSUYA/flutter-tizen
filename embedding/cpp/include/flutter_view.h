// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_VIEW_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_VIEW_H_

#include <flutter_tizen.h>

#include <atomic>
#include <memory>

// Wrapper around a |FlutterDesktopViewRef|.
//
// Represents a single Tizen window/view hosted by a Flutter engine. The
// implicit view (view id 0) is created by |FlutterApp::OnCreate| and its
// lifetime is tied to the app; secondary views returned by
// |FlutterApp::AddView| or |FlutterEngine::AddView| are owned by this
// wrapper and destroyed via |FlutterDesktopEngineRemoveView| when the
// wrapper goes out of scope.
class FlutterView {
 public:
  // Takes ownership of |view|. When |view_id| is
  // |FLUTTER_DESKTOP_IMPLICIT_VIEW_ID| the view is treated as borrowed and
  // the destructor does not attempt to remove it from the engine; removing
  // the implicit view requires shutting down the engine itself.
  FlutterView(FlutterDesktopEngineRef engine, FlutterDesktopViewRef view,
              FlutterDesktopViewId view_id,
              std::shared_ptr<std::atomic_bool> engine_alive = nullptr);

  ~FlutterView();

  FlutterView(const FlutterView&) = delete;
  FlutterView& operator=(const FlutterView&) = delete;

  FlutterDesktopViewId GetId() const { return view_id_; }
  FlutterDesktopViewRef GetRef() const { return view_; }
  bool IsImplicit() const {
    return view_id_ == FLUTTER_DESKTOP_IMPLICIT_VIEW_ID;
  }

 private:
  FlutterDesktopEngineRef engine_ = nullptr;
  FlutterDesktopViewRef view_ = nullptr;
  FlutterDesktopViewId view_id_ = FLUTTER_DESKTOP_IMPLICIT_VIEW_ID;
  std::shared_ptr<std::atomic_bool> engine_alive_;
};

#endif  // FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_VIEW_H_
