// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using Tizen.Applications;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Configuration for the hosted mini-app channel and staged bundle layout.
    /// </summary>
    public sealed class HostedFlutterAppHostOptions
    {
        /// <summary>
        /// The method channel exposed to the Flutter host application.
        /// </summary>
        public string ChannelName { get; set; } = "super_app/mini_app_host";

        /// <summary>
        /// The catalog file under the main app's Flutter assets directory.
        /// </summary>
        public string AppCatalogAssetPath { get; set; } = Path.Combine("assets", "mini_apps", "apps.json");

        /// <summary>
        /// The packaged mini-app bundle directory under the main app's Flutter assets directory.
        /// </summary>
        public string AppBundleAssetsDirectory { get; set; } = Path.Combine("assets", "mini_apps", "apps");

        /// <summary>
        /// The directory name used under the app data directory for staged bundles.
        /// </summary>
        public string StagedBundleDirectoryName { get; set; } = "mini_apps";

        /// <summary>
        /// The initial x offset for new hosted windows.
        /// </summary>
        public int WindowOffsetX { get; set; } = 80;

        /// <summary>
        /// The initial y offset for new hosted windows.
        /// </summary>
        public int WindowOffsetY { get; set; } = 80;

        /// <summary>
        /// The additional window offset applied for each running mini app.
        /// </summary>
        public int WindowOffsetStep { get; set; } = 32;

        /// <summary>
        /// The hosted mini-app window width.
        /// </summary>
        public int WindowWidth { get; set; } = 960;

        /// <summary>
        /// The hosted mini-app window height.
        /// </summary>
        public int WindowHeight { get; set; } = 540;
    }

    internal sealed class HostedFlutterAppHost : IDisposable
    {
        private readonly Dictionary<string, HostedFlutterAppDefinition> _appCatalog;
        private readonly Dictionary<string, HostedFlutterWindow> _runningApps =
            new Dictionary<string, HostedFlutterWindow>(StringComparer.Ordinal);
        private readonly HostedFlutterAppHostOptions _options;
        private readonly string _logPrefix;
        private readonly string _packagedBundleRoot;
        private readonly string _sharedIcuDataPath;
        private readonly string _stagedBundleRoot;
        private readonly MethodChannel _channel;

        public HostedFlutterAppHost(FlutterEngine engine, HostedFlutterAppHostOptions options)
        {
            if (engine == null)
            {
                throw new ArgumentNullException(nameof(engine));
            }
            if (!engine.IsValid)
            {
                throw new ArgumentException("engine must be valid", nameof(engine));
            }

            _options = options ?? throw new ArgumentNullException(nameof(options));
            if (string.IsNullOrWhiteSpace(_options.ChannelName))
            {
                throw new ArgumentException("ChannelName cannot be null or empty", nameof(options));
            }
            _logPrefix = ResolveLogPrefix(_options);

            var application = Application.Current
                ?? throw new InvalidOperationException("Hosted mini-app support requires an active Tizen application.");
            var directoryInfo = application.DirectoryInfo
                ?? throw new InvalidOperationException("Could not resolve application directories.");
            var resourceRoot = directoryInfo.Resource
                ?? throw new InvalidOperationException("Could not resolve the application resource directory.");
            var dataRoot = directoryInfo.Data
                ?? throw new InvalidOperationException("Could not resolve the application data directory.");

            _sharedIcuDataPath = Path.Combine(resourceRoot, "icudtl.dat");
            _packagedBundleRoot = Path.Combine(resourceRoot, "flutter_assets", _options.AppBundleAssetsDirectory);
            _stagedBundleRoot = Path.Combine(dataRoot, _options.StagedBundleDirectoryName);

            var catalogPath = Path.Combine(resourceRoot, "flutter_assets", _options.AppCatalogAssetPath);
            _appCatalog = HostedFlutterAppCatalog.Load(catalogPath)
                .Apps
                .Where(app => !string.IsNullOrWhiteSpace(app.Id))
                .ToDictionary(app => app.Id, StringComparer.Ordinal);

            PrepareMiniAppBundles();

            var messenger = new FlutterBinaryMessenger(engine.GetMessenger());
            _channel = new MethodChannel(_options.ChannelName, StandardMethodCodec.Instance, messenger);
            _channel.SetMethodCallHandler(HandleMethodCall);
        }

        public void ResumeAll()
        {
            foreach (var app in _runningApps.Values)
            {
                app.NotifyAppIsResumed();
            }
        }

        public void PauseAll()
        {
            foreach (var app in _runningApps.Values)
            {
                app.NotifyAppIsPaused();
            }
        }

        public void Dispose()
        {
            _channel.UnsetMethodCallHandler();
            foreach (var app in _runningApps.Values)
            {
                app.Dispose();
            }
            _runningApps.Clear();
        }

        private object HandleMethodCall(MethodCall call)
        {
            switch (call.Method)
            {
                case "listMiniApps":
                    return BuildMiniAppList();
                case "launchMiniApp":
                    LaunchMiniApp(ExtractMiniAppId(call.Arguments));
                    return true;
                case "closeMiniApp":
                    CloseMiniApp(ExtractMiniAppId(call.Arguments));
                    return true;
                default:
                    throw new MissingPluginException();
            }
        }

        private ArrayList BuildMiniAppList()
        {
            var apps = new ArrayList();
            foreach (var app in _appCatalog.Values)
            {
                var entry = new Hashtable
                {
                    ["id"] = app.Id,
                    ["title"] = app.Title ?? string.Empty,
                    ["description"] = app.Description ?? string.Empty,
                    ["installed"] = Directory.Exists(Path.Combine(_stagedBundleRoot, app.Id)),
                    ["running"] = _runningApps.ContainsKey(app.Id),
                };
                apps.Add(entry);
            }
            return apps;
        }

        private void PrepareMiniAppBundles()
        {
            Directory.CreateDirectory(_stagedBundleRoot);
            foreach (var app in _appCatalog.Values)
            {
                var source = Path.Combine(_packagedBundleRoot, app.Id);
                var destination = Path.Combine(_stagedBundleRoot, app.Id);
                CopyDirectoryRecursively(source, destination);
                LogInfo($"Prepared mini app bundle: {source} -> {destination}");
            }
        }

        private void LaunchMiniApp(string appId)
        {
            if (string.IsNullOrWhiteSpace(appId))
            {
                throw new FlutterException("bad-args", "launchMiniApp requires a mini app id.", null);
            }
            if (!_appCatalog.ContainsKey(appId))
            {
                throw new FlutterException("launch-failed", "Unknown mini app id.", null);
            }

            if (_runningApps.TryGetValue(appId, out var existing))
            {
                existing.NotifyAppIsResumed();
                return;
            }

            var bundlePath = Path.Combine(_stagedBundleRoot, appId);
            if (!Directory.Exists(Path.Combine(bundlePath, "flutter_assets")))
            {
                throw new FlutterException(
                    "launch-failed",
                    "Mini app bundle is missing from the app data path.",
                    bundlePath);
            }

            try
            {
                var offset = _runningApps.Count * _options.WindowOffsetStep;
                var window = new HostedFlutterWindow(
                    new HostedFlutterBundle(bundlePath),
                    _sharedIcuDataPath,
                    x: _options.WindowOffsetX + offset,
                    y: _options.WindowOffsetY + offset,
                    width: _options.WindowWidth,
                    height: _options.WindowHeight);
                window.NotifyAppIsResumed();
                _runningApps[appId] = window;
                LogInfo($"Launched mini app window: {appId}");
            }
            catch (FlutterException)
            {
                throw;
            }
            catch (Exception e)
            {
                throw new FlutterException(
                    "launch-failed",
                    "Failed to create a hosted mini app window.",
                    e.Message);
            }
        }

        private void CloseMiniApp(string appId)
        {
            if (string.IsNullOrWhiteSpace(appId))
            {
                throw new FlutterException("bad-args", "closeMiniApp requires a mini app id.", null);
            }
            if (_runningApps.TryGetValue(appId, out var app))
            {
                app.Dispose();
                _runningApps.Remove(appId);
                LogInfo($"Destroyed mini app window: {appId}");
            }
        }

        private static string ExtractMiniAppId(object arguments)
        {
            if (arguments is string id)
            {
                return id;
            }
            if (arguments is IDictionary map && map.Contains("id"))
            {
                return map["id"]?.ToString() ?? string.Empty;
            }
            return string.Empty;
        }

        private static void CopyDirectoryRecursively(string source, string destination)
        {
            if (!Directory.Exists(source))
            {
                TizenLog.Warn($"Mini app bundle source is missing: {source}");
                return;
            }

            if (Directory.Exists(destination))
            {
                Directory.Delete(destination, true);
            }

            Directory.CreateDirectory(destination);

            foreach (var directory in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
            {
                Directory.CreateDirectory(Path.Combine(destination, MakeRelativePath(source, directory)));
            }

            foreach (var file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
            {
                var relativePath = MakeRelativePath(source, file);
                var destinationFile = Path.Combine(destination, relativePath);
                var destinationDirectory = Path.GetDirectoryName(destinationFile);
                if (!string.IsNullOrEmpty(destinationDirectory))
                {
                    Directory.CreateDirectory(destinationDirectory);
                }
                File.Copy(file, destinationFile, true);
            }
        }

        private static string MakeRelativePath(string root, string path)
        {
            var normalizedRoot = root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return path.Substring(normalizedRoot.Length)
                .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }

        private void LogInfo(string message)
        {
            TizenLog.Info(message);
            Console.Error.WriteLine($"[{_logPrefix}] {message}");
        }

        private static string ResolveLogPrefix(HostedFlutterAppHostOptions options)
        {
            var slashIndex = options.ChannelName.IndexOf('/');
            if (slashIndex > 0)
            {
                return options.ChannelName.Substring(0, slashIndex);
            }
            return "hosted_flutter_app";
        }
    }

    [DataContract]
    internal sealed class HostedFlutterAppCatalog
    {
        [DataMember(Name = "apps")]
        public List<HostedFlutterAppDefinition> Apps { get; set; } = new List<HostedFlutterAppDefinition>();

        internal static HostedFlutterAppCatalog Load(string path)
        {
            if (!File.Exists(path))
            {
                TizenLog.Warn($"Hosted mini app catalog is missing: {path}");
                return new HostedFlutterAppCatalog();
            }

            try
            {
                using (var stream = File.OpenRead(path))
                {
                    var serializer = new DataContractJsonSerializer(typeof(HostedFlutterAppCatalog));
                    return serializer.ReadObject(stream) as HostedFlutterAppCatalog
                        ?? new HostedFlutterAppCatalog();
                }
            }
            catch (Exception e)
            {
                TizenLog.Error($"Failed to load hosted mini app catalog '{path}': {e}");
                return new HostedFlutterAppCatalog();
            }
        }
    }

    [DataContract]
    internal sealed class HostedFlutterAppDefinition
    {
        [DataMember(Name = "id")]
        public string Id { get; set; }

        [DataMember(Name = "title")]
        public string Title { get; set; }

        [DataMember(Name = "description")]
        public string Description { get; set; }
    }
}
