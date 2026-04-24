// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/services.dart';

/// A handle to a secondary view created via `TizenMultiView.addView`.
///
/// The [viewId] matches the identifier exposed on `FlutterView.viewId` and
/// can be looked up through `PlatformDispatcher.view(id: ...)`.
class TizenViewHandle {
  /// Creates a handle for the given view id.
  const TizenViewHandle(this.viewId);

  /// The unique identifier of the secondary view.
  final int viewId;

  @override
  String toString() => 'TizenViewHandle(viewId: $viewId)';
}

/// Static helpers for adding and removing Tizen platform windows at runtime.
///
/// Each call goes through the `flutter_tizen/multi_view` platform channel and
/// reaches `FlutterDesktopEngineAddView`/`FlutterDesktopEngineRemoveView` on
/// the native side. The implicit view (id 0) is created automatically with
/// the app and cannot be added or removed through this API.
class TizenMultiView {
  TizenMultiView._();

  static const _channel = MethodChannel('flutter_tizen/multi_view');

  /// Adds a new top-level Tizen window and registers it with the engine as a
  /// secondary view.
  ///
  /// [x], [y], [width] and [height] are physical pixels. When [width] or
  /// [height] is null or zero, the screen dimensions are used (matching the
  /// behaviour of `FlutterDesktopWindowProperties`).
  ///
  /// [transparent] controls whether the new window has an alpha channel, and
  /// [topLevel] requests the TIZEN_POLICY_LEVEL_TOP notification level so the
  /// window is rendered above regular app windows. Setting [topLevel] to true
  /// requires the `http://tizen.org/privilege/window.priority.set` privilege
  /// in `tizen-manifest.xml`.
  ///
  /// Returns a [TizenViewHandle] whose [TizenViewHandle.viewId] is valid
  /// once the returned future completes. Throws [PlatformException] if the
  /// engine rejected the registration or if the platform window could not
  /// be created.
  static Future<TizenViewHandle> addView({
    int x = 0,
    int y = 0,
    int? width,
    int? height,
    bool transparent = false,
    bool topLevel = false,
    double userPixelRatio = 0.0,
  }) async {
    if (width != null && width < 0) {
      throw ArgumentError.value(
        width,
        'width',
        'The view width must be non-negative.',
      );
    }
    if (height != null && height < 0) {
      throw ArgumentError.value(
        height,
        'height',
        'The view height must be non-negative.',
      );
    }
    if (userPixelRatio < 0.0) {
      throw ArgumentError.value(
        userPixelRatio,
        'userPixelRatio',
        'The user pixel ratio must be non-negative.',
      );
    }
    final int id = await _channel.invokeMethod<int>('addView', <String, Object?>{
          'x': x,
          'y': y,
          'width': width ?? 0,
          'height': height ?? 0,
          'transparent': transparent,
          'topLevel': topLevel,
          'userPixelRatio': userPixelRatio,
        }) ??
        -1;
    if (id < 0) {
      throw PlatformException(
        code: 'addView-failed',
        message: 'FlutterDesktopEngineAddView did not return a valid view id.',
      );
    }
    return TizenViewHandle(id);
  }

  /// Updates the geometry of a secondary view without recreating it.
  ///
  /// The [viewId] must identify a view created by [addView]. [x], [y],
  /// [width] and [height] are physical pixels. Passing null for a field keeps
  /// the current native value for that field.
  static Future<bool> updateView({
    required int viewId,
    int? x,
    int? y,
    int? width,
    int? height,
  }) async {
    if (viewId == 0) {
      throw ArgumentError.value(
        viewId,
        'viewId',
        'The implicit view (id 0) cannot be updated through this API.',
      );
    }
    if (width != null && width < 0) {
      throw ArgumentError.value(
        width,
        'width',
        'The view width must be non-negative.',
      );
    }
    if (height != null && height < 0) {
      throw ArgumentError.value(
        height,
        'height',
        'The view height must be non-negative.',
      );
    }
    return await _channel.invokeMethod<bool>('updateView', <String, Object?>{
          'viewId': viewId,
          'x': x,
          'y': y,
          'width': width,
          'height': height,
        }) ??
        false;
  }

  /// Removes a secondary view previously returned by `addView`.
  ///
  /// Attempting to remove the implicit view (id 0) throws [ArgumentError]
  /// because the implicit view is tied to the engine's own lifetime.
  static Future<bool> removeView(int viewId) async {
    if (viewId == 0) {
      throw ArgumentError.value(
        viewId,
        'viewId',
        'The implicit view (id 0) cannot be removed at runtime.',
      );
    }
    final bool ok =
        await _channel.invokeMethod<bool>('removeView', <String, Object?>{
          'viewId': viewId,
        }) ??
        false;
    return ok;
  }

  /// View ids of every view currently registered with the engine, including
  /// the implicit view.
  static Iterable<int> get registeredViewIds =>
      PlatformDispatcher.instance.views.map((FlutterView v) => v.viewId);
}
