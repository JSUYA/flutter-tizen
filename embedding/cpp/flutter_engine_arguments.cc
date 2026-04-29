// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/flutter_engine_arguments.h"

#include <algorithm>
#include <cerrno>

#include "tizen_log.h"

namespace {

static constexpr const char* kMetadataKeyEnableImepeller =
    "http://tizen.org/metadata/flutter_tizen/enable_impeller";
static constexpr const char* kMetadataKeyEnableFlutterGpu =
    "http://tizen.org/metadata/flutter_tizen/enable_flutter_gpu";

}  // namespace

FlutterEngineArguments::FlutterEngineArguments() {
  engine_args_ = ParseEngineArgs();
}

std::vector<std::string> FlutterEngineArguments::ParseEngineArgs() {
  std::vector<std::string> engine_args;
  char* id;
  if (app_get_id(&id) != 0) {
    TizenLog::Warn("The app ID is not found.");
    return engine_args;
  }

  std::string app_id = std::string(id);
  std::string temp_path("/home/owner/share/tmp/sdk_tools/" + app_id + ".rpm");
  free(id);

  auto file = fopen(temp_path.c_str(), "r");
  if (file) {
    char* line = nullptr;
    size_t len = 0;

    while (getline(&line, &len, file) > 0) {
      if (line[strlen(line) - 1] == '\n') {
        line[strlen(line) - 1] = 0;
      }
      engine_args.push_back(line);
    }
    free(line);
    fclose(file);

    if (remove(temp_path.c_str()) != 0) {
      TizenLog::Warn("Error removing file: %s", strerror(errno));
    }
  }

  app_info_h app_info = nullptr;
  if (app_manager_get_app_info(app_id.c_str(), &app_info) ==
      APP_MANAGER_ERROR_NONE) {
    is_impeller_enabled_ =
        ProcessMetadataFlag(engine_args, "--enable-impeller", app_info,
                            kMetadataKeyEnableImepeller);
    is_flutter_gpu_enabled_ =
        ProcessMetadataFlag(engine_args, "--enable-flutter-gpu", app_info,
                            kMetadataKeyEnableFlutterGpu);
    app_info_destroy(app_info);
  } else {
    TizenLog::Error("Failed to retrieve app info.");
  }

  for (const std::string& arg : engine_args) {
    TizenLog::Info("Enabled: %s", arg.c_str());
  }

  return engine_args;
}

bool FlutterEngineArguments::ProcessMetadataFlag(
    std::vector<std::string>& engine_args, const std::string& flag,
    app_info_h app_info, const std::string& metadata_key) {
  bool enabled = false;
  auto flag_it = std::find(engine_args.begin(), engine_args.end(), flag);
  bool flag_exists = (flag_it != engine_args.end());

  if (flag_exists) {
    enabled = true;
  }

  char* metadata_value = nullptr;
  if (app_info_get_metadata(app_info, metadata_key.c_str(), &metadata_value) ==
          APP_MANAGER_ERROR_NONE &&
      metadata_value != nullptr) {
    bool metadata_enabled = (std::string(metadata_value) == "true");
    free(metadata_value);

    if (!flag_exists && metadata_enabled) {
      enabled = true;
      engine_args.insert(engine_args.begin(), flag);
    } else if (flag_exists && !metadata_enabled) {
      enabled = false;
      engine_args.erase(flag_it);
    }
  }

  return enabled;
}
