# Flutter 3.41.2 compatibility update report

Date: 2026-03-01
Branch target: `feature/flutter-3.41.2-sync`

## 1) Objective
Update flutter-tizen tooling for compatibility with upstream Flutter 3.41.2, based on upstream `flutter_tools` changes and local smoke validation.

## 2) Upstream analysis (Flutter 3.38.x -> 3.41.2)

### 2.1 Release-level changes relevant to tooling integration
From Flutter release notes/changelog and local SDK diffs:
- Flutter 3.41 introduces tooling-level create workflow changes tied to shared Darwin plugin support.
- Flutter 3.41 tooling also evolved device discovery flows (wireless discovery pathways in `PollingDeviceDiscovery`).
- Flutter 3.41.2 itself is a patch-level release that bumps engine revision in the framework tag.

### 2.2 Concrete API deltas that affected flutter-tizen
Validated directly against Flutter SDK tag `3.41.2` (`90673a4eef275d1a6692c26ac80d6d746d41a73a`):

1. `CreateBase.addPlatformsOptions` signature changed:
- old: `addPlatformsOptions({String? customHelp})`
- new: `addPlatformsOptions({String? customHelp, required Map<String, String> allowedHelp})`

2. `CreateBase.createTemplateContext` signature changed:
- new optional parameter `bool darwin = false`

3. `PollingDeviceDiscovery.pollingGetDevices` signature changed:
- old: `pollingGetDevices({Duration? timeout})`
- new: `pollingGetDevices({Duration? timeout, bool forWirelessDiscovery = false})`

These were observed by compiling/analyzing flutter-tizen `lib/` against Flutter 3.41.2 sources.

## 3) Implemented changes

### 3.1 Version pin updates
Updated:
- `bin/internal/flutter.version`
  - `bd7a4a6b5576630823ca344e3e684c53aa1a0f46` -> `90673a4eef275d1a6692c26ac80d6d746d41a73a`
- `bin/internal/engine.version`
  - `fcd10a63f40a4e3656b21d2ee6003a090a6b47b7` -> `6c0baaebf70e0148f485f27d5616b3d3382da7bf`

Kept unchanged:
- `bin/internal/embedder.version` remains `dd2f6ba563596fa04d08c0b39c4a63a951c5a8f4` (latest published embedder release observed).

### 3.2 Tooling compatibility patches
Updated `lib/commands/create.dart`:
- Adjusted `addPlatformsOptions` override to match new required `allowedHelp` parameter.
- Added `platform` alias and merged `allowedHelp` map with Tizen entry.
- Added `darwin` parameter to `createTemplateContext` override and passed through to `super`.

Updated `lib/tizen_device_discovery.dart`:
- Adjusted `pollingGetDevices` override to include `forWirelessDiscovery` parameter.

## 4) Validation results

## 4.1 Static compatibility check (against Flutter 3.41.2 sources)
Command:
- `dart pub get --offline` (with writable local `PUB_CACHE` and temporary analysis-only pubspec)
- `dart analyze lib`

Result:
- Passed with no errors.
- 1 info-level lint remains (pre-existing style issue):
  - `commands/test.dart:51:7 Missing type annotation on a public API`

## 4.2 Version smoke check
Command:
- `dart run bin/flutter_tizen.dart --version --no-version-check`

Result:
- Success
- Reported:
  - Flutter-Tizen revision: `f68f184ae9`
  - Framework revision: `90673a4eef` (Flutter 3.41.2)
  - Engine revision: `6c0baaebf7`

## 4.3 Key CLI smoke checks
Commands:
- `dart run bin/flutter_tizen.dart --help`
- `dart run bin/flutter_tizen.dart create --help`
- `dart run bin/flutter_tizen.dart devices --help`

Result:
- All succeeded; command metadata and argument surfaces loaded correctly.
- `create --help` shows expected Tizen platform option and help text.

## 4.4 Wrapper-script smoke check (`bin/flutter-tizen --version`)
Status: blocked in this sandbox.
- Wrapper reaches Flutter bootstrap (`Building flutter tool... Resolving dependencies...`) and stalls/fails due offline/network restrictions during Flutter tool bootstrap.
- Direct `dart run` smoke checks were used as offline fallback to validate command wiring.

## 5) Remaining gaps / blockers
1. Artifact publication alignment
- `flutter-tizen/flutter` and `flutter-tizen/embedder` release cadence may lag framework pin updates.
- At reporting time, latest observed published release tags:
  - engine repo: `fcd10a6`
  - embedder repo: `dd2f6ba`
- If `6c0baa...` Tizen engine artifacts are not yet published, `precache`/build flows that download Tizen artifacts will fail until release artifacts are available.

2. Environment restrictions
- Top-level workspace `.git` is read-only in this environment, so branch/commit/push had to be performed from a writable clone.
- External DNS/network access is restricted for shell commands, limiting full wrapper-based end-to-end checks.

## 6) Sources
- Flutter 3.41.0 release notes/changelog:
  - https://docs.flutter.dev/release/release-notes/release-notes-3.41.0
- Flutter 3.38.0 release notes/changelog:
  - https://docs.flutter.dev/release/release-notes/release-notes-3.38.0
- Flutter breaking changes index:
  - https://docs.flutter.dev/release/breaking-changes
- Flutter SDK tag used for sync:
  - https://github.com/flutter/flutter/releases/tag/3.41.2
- Flutter commit introducing shared Darwin create changes:
  - https://github.com/flutter/flutter/commit/0b191ba123c
- flutter-tizen engine releases:
  - https://github.com/flutter-tizen/flutter/releases
- flutter-tizen embedder releases:
  - https://github.com/flutter-tizen/embedder/releases
