// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

/// Minimal API used by the FFI-only Tizen plugin sample app.
class SupportFfiPluginSample {
  const SupportFfiPluginSample._();

  /// Returns the current process pointer size.
  static int get pointerSize => sizeOf<IntPtr>();

  /// Returns the plugin registration style declared in pubspec.yaml.
  static String get registrationStyle => 'ffiPlugin';
}
