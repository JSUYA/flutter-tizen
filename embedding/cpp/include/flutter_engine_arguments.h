// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_ARGUMENTS_H_
#define FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_ARGUMENTS_H_

#include <app.h>
#include <app_info.h>
#include <app_manager.h>

#include <cerrno>
#include <string>
#include <vector>

// Handles parsing and management of Flutter engine arguments.
class FlutterEngineArguments {
 public:
  FlutterEngineArguments();
  virtual ~FlutterEngineArguments() = default;

  // Prevent copying.
  FlutterEngineArguments(FlutterEngineArguments const&) = delete;
  FlutterEngineArguments& operator=(FlutterEngineArguments const&) = delete;

  // Gets the list of parsed engine arguments.
  const std::vector<std::string>& GetArguments() const { return engine_args_; }

  // Whether the impeller is enabled or not.
  bool IsImpellerEnabled() const { return is_impeller_enabled_; }

  // Whether the flutter gpu is enabled or not.
  bool IsFlutterGpuEnabled() const { return is_flutter_gpu_enabled_; }

 private:
  // Reads engine arguments passed from the flutter-tizen tool.
  std::vector<std::string> ParseEngineArgs();

  // Processes a metadata flag by checking both engine arguments and application
  // metadata.
  bool ProcessMetadataFlag(std::vector<std::string>& engine_args,
                           const std::string& flag, bool has_metadata_value,
                           bool metadata_enabled);

  // The list of parsed engine arguments.
  std::vector<std::string> engine_args_;

  // Whether the impeller is enabled or not.
  bool is_impeller_enabled_ = false;

  // Whether the flutter gpu is enabled or not.
  bool is_flutter_gpu_enabled_ = false;
};

#endif /* FLUTTER_TIZEN_EMBEDDING_CPP_INCLUDE_FLUTTER_ENGINE_ARGUMENTS_H_ */
