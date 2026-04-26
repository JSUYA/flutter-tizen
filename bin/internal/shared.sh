#!/usr/bin/env bash
# Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `shared.bat` script in the same directory to ensure that Flutter continue
# to work across all platforms!
#
# -------------------------------------------------------------------------- #

set -e

# Needed because if it is set, cd may print the path it changed to.
unset CDPATH

FLUTTER_REPO="https://github.com/flutter/flutter.git"

if [[ -z "$BIN_DIR" ]]; then
  >&2 echo "BIN_DIR is not set."
  exit 1
fi
ROOT_DIR="$(cd "${BIN_DIR}/.." ; pwd -P)"
FLUTTER_DIR="$ROOT_DIR/flutter"
SNAPSHOT_PATH="$ROOT_DIR/bin/cache/flutter-tizen.snapshot"

FLUTTER_EXE="$FLUTTER_DIR/bin/flutter"
DART_EXE="$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart"
FLUTTER_PATCH_DIR="$ROOT_DIR/patches/flutter_tools"
FLUTTER_PATCH_STAMP_PATH="$FLUTTER_DIR/bin/cache/flutter-tizen-patches.stamp"

function apply_flutter_patches() {
  if [[ ! -d "$FLUTTER_PATCH_DIR" ]]; then
    return
  fi

  local patch_revision=""
  patch_revision="$(git --git-dir="$ROOT_DIR/.git" --work-tree="$ROOT_DIR" \
    rev-parse HEAD:patches/flutter_tools 2>/dev/null || true)"
  local patch_state_changed=0
  if [[ -n "$patch_revision" ]]; then
    if [[ ! -f "$FLUTTER_PATCH_STAMP_PATH" ]]; then
      patch_state_changed=1
    elif [[ "$patch_revision" != "$(cat "$FLUTTER_PATCH_STAMP_PATH")" ]]; then
      patch_state_changed=1
      git -C "$FLUTTER_DIR" reset --hard
      git -C "$FLUTTER_DIR" checkout "$(cat "$ROOT_DIR/bin/internal/flutter.version")" > /dev/null
    fi
  fi

  local patch_applied=0
  shopt -s nullglob
  for patch_file in "$FLUTTER_PATCH_DIR"/*.patch; do
    if git -C "$FLUTTER_DIR" apply --unidiff-zero --check "$patch_file" > /dev/null 2>&1; then
      git -C "$FLUTTER_DIR" apply --unidiff-zero --whitespace=nowarn "$patch_file"
      patch_applied=1
    elif git -C "$FLUTTER_DIR" apply --unidiff-zero --reverse --check "$patch_file" > /dev/null 2>&1; then
      continue
    else
      >&2 echo "Failed to apply Flutter patch: $patch_file"
      exit 1
    fi
  done
  shopt -u nullglob

  if [[ "$patch_applied" == "1" || "$patch_state_changed" == "1" ]]; then
    rm -f "$FLUTTER_DIR/bin/cache/flutter_tools.stamp"
  fi
  if [[ -n "$patch_revision" ]]; then
    mkdir -p "$FLUTTER_DIR/bin/cache"
    echo "$patch_revision" > "$FLUTTER_PATCH_STAMP_PATH"
  fi
}

function update_flutter() {
  if [[ -e "$FLUTTER_DIR" && ! -d "$FLUTTER_DIR/.git" ]]; then
    >&2 echo "$FLUTTER_DIR is not a git directory. Remove it and try again."
    exit 1
  fi

  # Clone flutter repo if not installed.
  if [[ ! -d "$FLUTTER_DIR" ]]; then
    git clone "$FLUTTER_REPO" "$FLUTTER_DIR"
  fi

  # GIT_DIR and GIT_WORK_TREE are used in the git command.
  export GIT_DIR="$FLUTTER_DIR/.git"
  export GIT_WORK_TREE="$FLUTTER_DIR"

  # Update flutter repo if needed.
  local version="$(cat "$ROOT_DIR/bin/internal/flutter.version")"
  if [[ "$version" != "$(git rev-parse HEAD)" ]]; then
    git reset --hard
    git clean -xdf
    git fetch --tags "$FLUTTER_REPO" "$version"
    git checkout FETCH_HEAD

    # Invalidate the cache.
    rm -fr "$ROOT_DIR/bin/cache"
  fi

  if [[ "$version" != "$(git rev-parse HEAD)" ]]; then
    >&2 echo "Something went wrong while upgrading the Flutter SDK."
    >&2 echo "Remove the directory $FLUTTER_DIR and try again."
    exit 1
  fi

  unset GIT_DIR
  unset GIT_WORK_TREE

  apply_flutter_patches

  # Invalidate the flutter cache.
  local compilekey="$version:"
  local stamp_path="$FLUTTER_DIR/bin/cache/flutter_tools.stamp"
  if [[ ! -f "$stamp_path" || "$compilekey" != "$(cat "$stamp_path")" ]]; then
    "$FLUTTER_EXE" > /dev/null
  fi
}

function update_flutter_tizen() {
  mkdir -p "$ROOT_DIR/bin/cache"

  local revision="$(git --git-dir="$ROOT_DIR/.git" rev-parse HEAD)"
  local stamp_path="$ROOT_DIR/bin/cache/flutter-tizen.stamp"

  if [[ ! -f "$SNAPSHOT_PATH" || ! -s "$stamp_path" || "$revision" != "$(cat "$stamp_path")"
        || "$ROOT_DIR/pubspec.yaml" -nt "$ROOT_DIR/pubspec.lock" ]]; then
    echo "Running pub upgrade..."
    (cd "$ROOT_DIR" && "$FLUTTER_EXE" pub upgrade) || {
      >&2 echo "Error: Unable to 'pub upgrade' flutter-tizen."
      exit 1
    }

    echo "Compiling flutter-tizen..."
    "$DART_EXE" --disable-dart-dev --no-enable-mirrors \
                --snapshot="$SNAPSHOT_PATH" \
                --packages="$ROOT_DIR/.dart_tool/package_config.json" \
                "$ROOT_DIR/bin/flutter_tizen.dart"

    echo "$revision" > "$stamp_path"
  fi
}

function exec_snapshot() {
  exec "$DART_EXE" --disable-dart-dev \
                   --packages="$ROOT_DIR/.dart_tool/package_config.json" \
                   "$SNAPSHOT_PATH" "$@"
}
