// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.IO;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Handles parsing and management of Flutter engine arguments.
    /// </summary>
    public class FlutterEngineArguments
    {
        private const int AppManagerErrorNone = 0;
        private const string MetadataKeyEnableImepeller = "http://tizen.org/metadata/flutter_tizen/enable_impeller";
        private const string MetadataKeyEnableFlutterGpu = "http://tizen.org/metadata/flutter_tizen/enable_flutter_gpu";
        private const string MetadataKeyWindowMsaaSamples = "http://tizen.org/metadata/flutter_tizen/window_msaa_samples";
        private const string WindowMsaaSamplesArgument = "--tizen-window-msaa-samples=";

        private sealed class FlutterMetadataFlags
        {
            internal bool HasImpeller { get; set; }
            internal bool ImpellerEnabled { get; set; }
            internal bool HasFlutterGpu { get; set; }
            internal bool FlutterGpuEnabled { get; set; }
            internal bool HasWindowMsaaSamples { get; set; }
            internal string WindowMsaaSamples { get; set; }
        }

        /// <summary>
        /// Gets the list of parsed engine arguments.
        /// </summary>
        public IList<string> Arguments { get; private set; }

        /// <summary>
        /// Gets whether the impeller is enabled or not.
        /// </summary>
        public bool IsImpellerEnabled { get; private set; } = false;

        /// <summary>
        /// Gets whether the flutter gpu is enabled or not.
        /// </summary>
        public bool IsFlutterGpuEnabled { get; private set; } = false;

        /// <summary>
        /// Gets whether the flutter tizen experimental is enabled or not.
        /// </summary>
        public bool IsFlutterTizenExperimentalEnabled { get; private set; } = false;

        /// <summary>
        /// Creates a <see cref="FlutterEngineArguments"/> instance and parses engine arguments.
        /// </summary>
        public FlutterEngineArguments()
        {
            Arguments = ParseEngineArgs();
        }

        /// <summary>
        /// Reads engine arguments passed from the flutter-tizen tool.
        /// </summary>
        private IList<string> ParseEngineArgs()
        {
            var result = new List<string>();
            string appId = Application.Current.ApplicationInfo.ApplicationId;
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";

            if (File.Exists(tempPath))
            {
                try
                {
                    var lines = File.ReadAllText(tempPath).Trim().Split('\n');
                    foreach (string line in lines)
                    {
                        result.Add(line);
                    }
                    File.Delete(tempPath);
                }
                catch (Exception ex)
                {
                    TizenLog.Warn($"Error while processing a file: {ex}");
                }
            }

            var metadata = GetMetadataFlags(appId);

            IsImpellerEnabled = ProcessMetadataFlag(
                result, "--enable-impeller", metadata.HasImpeller, metadata.ImpellerEnabled);
            IsFlutterGpuEnabled = ProcessMetadataFlag(
                result, "--enable-flutter-gpu", metadata.HasFlutterGpu, metadata.FlutterGpuEnabled);
            if (metadata.HasWindowMsaaSamples)
            {
                string samples = metadata.WindowMsaaSamples;
                if (samples == "0" || samples == "2" || samples == "4")
                {
                    result.RemoveAll(arg => arg.StartsWith(WindowMsaaSamplesArgument, StringComparison.Ordinal));
                    result.Insert(0, WindowMsaaSamplesArgument + samples);
                }
                else
                {
                    TizenLog.Warn($"Unsupported window MSAA sample count: {samples}");
                }
            }
            IsFlutterTizenExperimentalEnabled = result.Contains("--dart-define=USE_FLUTTER_TIZEN_EXPERIMENTAL=true");

            foreach (string flag in result)
            {
                TizenLog.Info($"Enabled: {flag}");
            }
            return result;
        }

        private static FlutterMetadataFlags GetMetadataFlags(string appId)
        {
            var metadata = new FlutterMetadataFlags();
            if (app_manager_get_app_info(appId, out IntPtr appInfo) != AppManagerErrorNone)
            {
                TizenLog.Error("Failed to retrieve app info.");
                return metadata;
            }

            try
            {
                AppInfoMetadataCallback callback = (key, value, userData) =>
                {
                    if (key == MetadataKeyEnableImepeller)
                    {
                        metadata.HasImpeller = true;
                        metadata.ImpellerEnabled = value == "true";
                    }
                    else if (key == MetadataKeyEnableFlutterGpu)
                    {
                        metadata.HasFlutterGpu = true;
                        metadata.FlutterGpuEnabled = value == "true";
                    }
                    else if (key == MetadataKeyWindowMsaaSamples)
                    {
                        metadata.HasWindowMsaaSamples = true;
                        metadata.WindowMsaaSamples = value;
                    }
                    return !(metadata.HasImpeller && metadata.HasFlutterGpu && metadata.HasWindowMsaaSamples);
                };

                if (app_info_foreach_metadata(appInfo, callback, IntPtr.Zero) != AppManagerErrorNone)
                {
                    TizenLog.Error("Failed to get app metadata.");
                }
            }
            finally
            {
                app_info_destroy(appInfo);
            }
            return metadata;
        }

        /// <summary>
        /// Processes a metadata flag by checking both engine arguments and application metadata.
        /// </summary>
        private static bool ProcessMetadataFlag(
            List<string> result, string flag, bool hasMetadataValue, bool metadataEnabled)
        {
            bool enabled = false;
            bool flagExists = result.Contains(flag);
            if (flagExists)
            {
                enabled = true;
            }

            if (hasMetadataValue)
            {
                if (!flagExists && metadataEnabled)
                {
                    enabled = true;
                    result.Insert(0, flag);
                }
                else if (flagExists && !metadataEnabled)
                {
                    enabled = false;
                    result.Remove(flag);
                }
            }
            return enabled;
        }
    }
}
