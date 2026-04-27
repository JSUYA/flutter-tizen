// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_view.h"

#include <utility>

FlutterView::FlutterView(FlutterDesktopEngineRef engine,
                         FlutterDesktopViewRef view,
                         FlutterDesktopViewId view_id,
                         std::shared_ptr<std::atomic_bool> engine_alive)
    : engine_(engine),
      view_(view),
      view_id_(view_id),
      engine_alive_(std::move(engine_alive)) {}

FlutterView::~FlutterView() {
  if (!view_ || !engine_) {
    return;
  }
  // The implicit view is torn down as part of engine shutdown so the
  // wrapper intentionally leaves it untouched. Secondary views must be
  // explicitly removed via the async C API so the Dart framework also
  // observes the removal. The embedder keeps the native view alive until
  // FlutterEngineRemoveView acknowledges removal, and drains acknowledged
  // pending destruction during engine shutdown.
  if (view_id_ == FLUTTER_DESKTOP_IMPLICIT_VIEW_ID) {
    return;
  }
  if (engine_alive_ && !engine_alive_->load()) {
    return;
  }
  FlutterDesktopEngineRemoveView(engine_, view_id_, nullptr, nullptr);
}
