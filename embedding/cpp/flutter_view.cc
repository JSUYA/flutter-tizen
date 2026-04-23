// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_view.h"

FlutterView::FlutterView(FlutterDesktopEngineRef engine,
                         FlutterDesktopViewRef view,
                         FlutterDesktopViewId view_id)
    : engine_(engine), view_(view), view_id_(view_id) {}

FlutterView::~FlutterView() {
  if (!view_ || !engine_) {
    return;
  }
  // The implicit view is torn down as part of engine shutdown so the
  // wrapper intentionally leaves it untouched. Secondary views must be
  // explicitly removed via the async C API so the Dart framework also
  // observes the removal. The native view is kept alive by the C API until
  // FlutterEngineRemoveView acknowledges removal, so this wrapper can fire
  // and forget safely.
  if (view_id_ == FLUTTER_DESKTOP_IMPLICIT_VIEW_ID) {
    return;
  }
  FlutterDesktopEngineRemoveView(engine_, view_id_, nullptr, nullptr);
}
