// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Describes a hosted mini-app bundle located under a host application's data directory.
    /// </summary>
    internal sealed class HostedFlutterBundle
    {
        /// <summary>
        /// Creates a bundle description from the provided bundle root.
        /// </summary>
        public HostedFlutterBundle(string bundlePath)
        {
            if (string.IsNullOrWhiteSpace(bundlePath))
            {
                throw new ArgumentException("bundlePath cannot be null or empty", nameof(bundlePath));
            }
            BundlePath = Path.GetFullPath(bundlePath);
            AssetsPath = Path.Combine(BundlePath, "flutter_assets");
            LibraryDirectory = Path.Combine(BundlePath, "lib");
            AotLibraryPath = Path.Combine(LibraryDirectory, "libapp.so");
            Manifest = HostedFlutterBundleManifest.Load(BundlePath);
        }

        /// <summary>
        /// The root directory of the bundle.
        /// </summary>
        public string BundlePath { get; }

        /// <summary>
        /// The bundle's Flutter assets directory.
        /// </summary>
        public string AssetsPath { get; }

        /// <summary>
        /// The bundle's library directory.
        /// </summary>
        public string LibraryDirectory { get; }

        /// <summary>
        /// The bundle's AOT library path. Debug bundles may not contain this file.
        /// </summary>
        public string AotLibraryPath { get; }

        /// <summary>
        /// The generated manifest describing hosted plugin registration.
        /// </summary>
        public HostedFlutterBundleManifest Manifest { get; }

        internal string ResolveLibraryPath(string library)
        {
            if (Path.IsPathRooted(library))
            {
                return library;
            }
            return Path.Combine(LibraryDirectory, library);
        }
    }

    /// <summary>
    /// Hosts a mini-app bundle in a dedicated native window.
    /// </summary>
    internal sealed class HostedFlutterWindow : IDisposable
    {
        private readonly NativePluginLoader _pluginLoader = new NativePluginLoader();

        /// <summary>
        /// Creates a new hosted window for the given bundle.
        /// </summary>
        public HostedFlutterWindow(
            HostedFlutterBundle bundle,
            string sharedIcuDataPath,
            string dartEntrypoint = "",
            int x = 0,
            int y = 0,
            int width = 0,
            int height = 0)
        {
            Bundle = bundle ?? throw new ArgumentNullException(nameof(bundle));
            if (string.IsNullOrWhiteSpace(sharedIcuDataPath))
            {
                throw new ArgumentException("sharedIcuDataPath cannot be null or empty", nameof(sharedIcuDataPath));
            }

            try
            {
                var aotLibraryPath = File.Exists(Bundle.AotLibraryPath) ? Bundle.AotLibraryPath : string.Empty;
                Engine = new FlutterEngine(
                    Bundle.AssetsPath,
                    sharedIcuDataPath,
                    aotLibraryPath,
                    dartEntrypoint);
                if (!Engine.IsValid)
                {
                    throw new InvalidOperationException("Could not create a Flutter engine.");
                }

                var windowProperties = new FlutterDesktopWindowProperties
                {
                    x = x,
                    y = y,
                    width = width,
                    height = height,
                    transparent = false,
                    focusable = true,
                    top_level = false,
                    renderer_type = FlutterDesktopRendererType.kEGL,
                    user_pixel_ratio = 0.0,
                    window_handle = IntPtr.Zero,
                    pointing_device_support = true,
                    floating_menu_support = true,
                };

                View = FlutterDesktopViewCreateFromNewWindow(ref windowProperties, Engine.Engine);
                if (View.IsInvalid)
                {
                    throw new InvalidOperationException("Could not create a hosted Flutter window.");
                }

                _pluginLoader.RegisterPlugins(Bundle.Manifest, Bundle, Engine.GetRegistrarForPlugin);
            }
            catch
            {
                Dispose();
                throw;
            }
        }

        /// <summary>
        /// The bundle currently hosted by the window.
        /// </summary>
        public HostedFlutterBundle Bundle { get; }

        /// <summary>
        /// The Flutter engine backing the hosted mini-app.
        /// </summary>
        public FlutterEngine Engine { get; private set; }

        /// <summary>
        /// The native view showing the hosted mini-app.
        /// </summary>
        public FlutterDesktopView View { get; private set; } = new FlutterDesktopView();

        /// <summary>
        /// Closes the window and releases native resources.
        /// </summary>
        public void Dispose()
        {
            if (Engine != null && Engine.IsValid)
            {
                Engine.NotifyAppIsDetached();
            }
            if (View != null && !View.IsInvalid)
            {
                // FlutterDesktopViewDestroy stops the engine and releases all
                // native resources.  Do NOT call Engine.Shutdown() beforehand:
                // the native Shutdown deletes the engine object, and the
                // subsequent ViewDestroy would access freed memory.
                FlutterDesktopViewDestroy(View);
                View = new FlutterDesktopView();
            }
            else if (Engine != null && Engine.IsValid)
            {
                Engine.Shutdown();
            }
            _pluginLoader.Dispose();
            Engine = null;
        }

        /// <summary>
        /// Notifies that the hosted mini-app is resumed.
        /// </summary>
        public void NotifyAppIsResumed()
        {
            if (Engine != null && Engine.IsValid)
            {
                Engine.NotifyAppIsResumed();
            }
        }

        /// <summary>
        /// Notifies that the hosted mini-app is paused.
        /// </summary>
        public void NotifyAppIsPaused()
        {
            if (Engine != null && Engine.IsValid)
            {
                Engine.NotifyAppIsPaused();
            }
        }
    }

    /// <summary>
    /// Manifest describing hosted native plugin registration for a mini-app bundle.
    /// </summary>
    [DataContract]
    internal sealed class HostedFlutterBundleManifest
    {
        /// <summary>
        /// The manifest schema version.
        /// </summary>
        [DataMember(Name = "schemaVersion")]
        public int SchemaVersion { get; set; } = 1;

        /// <summary>
        /// Native plugins that need to be registered for this bundle.
        /// </summary>
        [DataMember(Name = "plugins")]
        public List<HostedNativePlugin> Plugins { get; set; } = new List<HostedNativePlugin>();

        internal static HostedFlutterBundleManifest Load(string bundlePath)
        {
            var manifestPath = Path.Combine(bundlePath, "flutter_assets", "hosted_bundle_manifest.json");
            if (!File.Exists(manifestPath))
            {
                return new HostedFlutterBundleManifest();
            }

            using (var stream = File.OpenRead(manifestPath))
            {
                var serializer = new DataContractJsonSerializer(typeof(HostedFlutterBundleManifest));
                return serializer.ReadObject(stream) as HostedFlutterBundleManifest
                    ?? new HostedFlutterBundleManifest();
            }
        }
    }

    /// <summary>
    /// Hosted native plugin descriptor.
    /// </summary>
    [DataContract]
    internal sealed class HostedNativePlugin
    {
        /// <summary>
        /// The plugin package name.
        /// </summary>
        [DataMember(Name = "name")]
        public string Name { get; set; }

        /// <summary>
        /// The library containing the registration symbol.
        /// </summary>
        [DataMember(Name = "library")]
        public string Library { get; set; }

        /// <summary>
        /// The exported registration symbol.
        /// </summary>
        [DataMember(Name = "registerSymbol")]
        public string RegisterSymbol { get; set; }
    }

    internal sealed class NativePluginLoader : IDisposable
    {
        private readonly Dictionary<string, IntPtr> _handles = new Dictionary<string, IntPtr>();

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void RegisterPluginDelegate(FlutterDesktopPluginRegistrar registrar);

        public void RegisterPlugins(
            HostedFlutterBundleManifest manifest,
            HostedFlutterBundle bundle,
            Func<string, FlutterDesktopPluginRegistrar> getRegistrarForPlugin)
        {
            foreach (var plugin in manifest.Plugins)
            {
                IntPtr handle = LoadLibrary(bundle.ResolveLibraryPath(plugin.Library));
                IntPtr symbol = dlsym(handle, plugin.RegisterSymbol);
                if (symbol == IntPtr.Zero)
                {
                    throw new MissingMethodException(
                        $"Could not find registration symbol '{plugin.RegisterSymbol}' in '{plugin.Library}': {GetDlError()}");
                }
                var register = (RegisterPluginDelegate)Marshal.GetDelegateForFunctionPointer(
                    symbol, typeof(RegisterPluginDelegate));
                register(getRegistrarForPlugin(plugin.Name));
            }
        }

        public void Dispose()
        {
            foreach (var handle in _handles.Values)
            {
                if (handle != IntPtr.Zero)
                {
                    dlclose(handle);
                }
            }
            _handles.Clear();
        }

        private IntPtr LoadLibrary(string path)
        {
            if (_handles.TryGetValue(path, out IntPtr existing))
            {
                return existing;
            }

            IntPtr handle = dlopen(path, RtldNow | RtldLocal);
            if (handle == IntPtr.Zero)
            {
                throw new DllNotFoundException($"Could not load native plugin '{path}': {GetDlError()}");
            }
            _handles[path] = handle;
            return handle;
        }

        private static string GetDlError()
        {
            IntPtr error = dlerror();
            return error == IntPtr.Zero ? "unknown dlopen error" : (Marshal.PtrToStringAnsi(error) ?? "unknown dlopen error");
        }

        private const int RtldNow = 2;
        private const int RtldLocal = 0;

        [DllImport("libdl.so.2")]
        private static extern IntPtr dlopen(string fileName, int flags);

        [DllImport("libdl.so.2")]
        private static extern IntPtr dlsym(IntPtr handle, string symbol);

        [DllImport("libdl.so.2")]
        private static extern int dlclose(IntPtr handle);

        [DllImport("libdl.so.2")]
        private static extern IntPtr dlerror();
    }
}
