﻿// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using Tizen.NUI;
using Tizen.NUI.BaseComponents;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Displays a Flutter screen in a Tizen application.
    /// </summary>
    public class NUIFlutterView : ImageView
    {
        /// <summary>
        /// The Flutter engine instance.
        /// </summary>
        public FlutterEngine Engine { get; set; } = null;

        /// <summary>
        /// The Flutter view instance handle.
        /// </summary>
        private FlutterDesktopView View { get; set; } = new FlutterDesktopView();

        /// <summary>
        /// Whether the view is running.
        /// </summary>
        public bool IsRunning => !View.IsInvalid;

        /// <summary>
        /// When the view last received a touch event in milliseconds.
        /// </summary>
        private uint _lastTouchEventTime = 0;

        /// <summary>
        /// The current width of the view.
        /// </summary>
        public int Width => Size2D.Width;

        /// <summary>
        /// The current height of the view.
        /// </summary>
        public int Height => Size2D.Height;

        /// <summary>
        /// Starts running the view with the associated engine, creating if not set.
        /// </summary>
        /// <remarks>
        /// <see cref="Engine"/> must not be set again after this call.
        /// <see cref="Destroy"/> must be called if the view is no longer used.
        /// </remarks>
        public bool RunEngine()
        {
            if (IsRunning)
            {
                TizenLog.Error("The engine is already running.");
                return false;
            }

            if (Engine == null)
            {
                Engine = new FlutterEngine("", new List<string>());
            }

            if (!Engine.IsValid)
            {
                TizenLog.Error("Could not create a Flutter engine.");
                return false;
            }

            Type baseType = typeof(NativeImageQueue).BaseType.BaseType.BaseType;
            FieldInfo field = baseType.GetField("swigCPtr", BindingFlags.NonPublic | BindingFlags.Instance);
            NativeImageQueue nativeImageQueue =
                new NativeImageQueue((uint)Width, (uint)Height, NativeImageQueue.ColorFormat.RGBA8888);
            HandleRef nativeImageQueueRef = (HandleRef)field.GetValue(nativeImageQueue);
            SetImage(nativeImageQueue.GenerateUrl().ToString());

            Type imageViewBaseType = typeof(ImageView).BaseType.BaseType.BaseType.BaseType;
            FieldInfo imageViewField =
                imageViewBaseType.GetField("swigCPtr", BindingFlags.NonPublic | BindingFlags.Instance);
            HandleRef imageViewRef = (HandleRef)imageViewField.GetValue(this);

            var viewProperties = new FlutterDesktopViewProperties
            {
                width = Width,
                height = Height,
            };

            View = FlutterDesktopViewCreateFromImageView(
                ref viewProperties, Engine.Engine, imageViewRef.Handle, nativeImageQueueRef.Handle,
                NUIApplication.GetDefaultWindow().GetNativeId());
            if (View.IsInvalid)
            {
                TizenLog.Error("Could not launch a Flutter view.");
                return false;
            }

            Focusable = true;
            KeyEvent += (object s, KeyEventArgs e) =>
            {
                FlutterDesktopViewOnKeyEvent(
                    View, e.Key.KeyPressedName, e.Key.KeyPressed, (uint)e.Key.KeyModifier, (uint)e.Key.KeyCode,
                    e.Key.State == Key.StateType.Down);
                return true;
            };

            TouchEvent += (object s, TouchEventArgs e) =>
            {
                if (_lastTouchEventTime == e.Touch.GetTime())
                {
                    return false;
                }
                FocusManager.Instance.SetCurrentFocusView(this);

                FlutterDesktopPointerEventType type;
                switch (e.Touch.GetState(0))
                {
                    case PointStateType.Down:
                    default:
                        type = FlutterDesktopPointerEventType.kPointerDown;
                        break;
                    case PointStateType.Up:
                        type = FlutterDesktopPointerEventType.kPointerUp;
                        break;
                    case PointStateType.Motion:
                        type = FlutterDesktopPointerEventType.kPointerMove;
                        break;
                }
                FlutterDesktopViewOnPointerEvent(
                    View, type, e.Touch.GetLocalPosition(0).X, e.Touch.GetLocalPosition(0).Y, e.Touch.GetTime(),
                    e.Touch.GetDeviceId(0));

                _lastTouchEventTime = e.Touch.GetTime();
                return true;
            };

            return true;
        }

        /// <summary>
        /// Terminates the running view and the associated engine.
        /// </summary>
        public void Destroy()
        {
            if (IsRunning)
            {
                FlutterDesktopViewDestroy(View);
                Engine = null;
                View = new FlutterDesktopView();
            }
        }

        /// <summary>
        /// Resizes the view.
        /// </summary>
        public void Resize(int width, int height)
        {
            Debug.Assert(IsRunning);

            if (Width != width || Height != height)
            {
                FlutterDesktopViewResize(View, width, height);
            }
        }
    }
}
