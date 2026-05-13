// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

typedef _GetPidNative = Int32 Function();
typedef _GetPidDart = int Function();

/// Minimal API used by the FFI-only Tizen plugin sample app.
class SupportFfiPluginSample {
  const SupportFfiPluginSample._();

  static final _GetPidDart _getPid = _openLibc().lookupFunction<_GetPidNative, _GetPidDart>(
    'getpid',
  );

  /// Returns the current process id from libc through `dart:ffi`.
  static int get processId => _getPid();

  /// Returns the plugin registration style declared in pubspec.yaml.
  static String get registrationStyle => 'ffiPlugin';
}

DynamicLibrary _openLibc() {
  if (Platform.isLinux || Platform.isAndroid) {
    return DynamicLibrary.open(Platform.isAndroid ? 'libc.so' : 'libc.so.6');
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  }
  throw UnsupportedError('This sample only supports libc-based platforms.');
}
