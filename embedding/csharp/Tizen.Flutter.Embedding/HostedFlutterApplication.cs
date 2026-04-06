// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A Flutter application that exposes a hosted mini-app channel and stages mini-app bundles.
    /// </summary>
    public class HostedFlutterApplication : FlutterApplication
    {
        private HostedFlutterAppHost _hostedAppHost;

        /// <summary>
        /// Allows derived applications to register plugins after the host engine is created.
        /// </summary>
        protected virtual void RegisterPlugins()
        {
        }

        /// <summary>
        /// Allows derived applications to customize hosted mini-app settings.
        /// </summary>
        protected virtual void ConfigureHostedFlutterAppHost(HostedFlutterAppHostOptions options)
        {
        }

        /// <inheritdoc/>
        protected override void OnCreate()
        {
            base.OnCreate();

            RegisterPlugins();

            var options = new HostedFlutterAppHostOptions();
            ConfigureHostedFlutterAppHost(options);
            _hostedAppHost = new HostedFlutterAppHost(Engine, options);
        }

        /// <inheritdoc/>
        protected override void OnResume()
        {
            base.OnResume();
            _hostedAppHost?.ResumeAll();
        }

        /// <inheritdoc/>
        protected override void OnPause()
        {
            _hostedAppHost?.PauseAll();
            base.OnPause();
        }

        /// <inheritdoc/>
        protected override void OnTerminate()
        {
            _hostedAppHost?.Dispose();
            _hostedAppHost = null;
            base.OnTerminate();
        }
    }
}
