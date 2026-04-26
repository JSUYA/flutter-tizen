@ECHO off
REM Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

REM ---------------------------------- NOTE ----------------------------------
REM
REM Please keep the logic in this file consistent with the logic in the
REM `shared.sh` script in the same directory to ensure that Flutter & Dart continue to
REM work across all platforms!
REM
REM --------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

SET flutter_repo=https://github.com/flutter/flutter.git

SET cache_dir=%ROOT_DIR%\bin\cache
SET flutter_dir=%ROOT_DIR%\flutter
SET snapshot_path=%ROOT_DIR%\bin\cache\flutter-tizen.snapshot
SET flutter_exe=%flutter_dir%\bin\flutter.bat
SET dart_exe=%flutter_dir%\bin\cache\dart-sdk\bin\dart.exe
SET flutter_patch_dir=%ROOT_DIR%\patches\flutter_tools
SET flutter_patch_stamp_path=%flutter_dir%\bin\cache\flutter-tizen-patches.stamp

SHIFT & CALL :%~1
GOTO :EOF

:update_flutter
  IF EXIST "%flutter_dir%" IF NOT EXIST "%flutter_dir%\.git\" (
    ECHO Error: %flutter_dir% is not a git directory. Remove it and try again. 1>&2
    EXIT /B 1
  )

  REM Clone flutter repo if not installed.
  IF NOT EXIST "%flutter_dir%" (
    git clone "%flutter_repo%" "%flutter_dir%" || (
      ECHO Error: Failed to download the flutter repo from %flutter_repo%. 1>&2
      EXIT /B
    )
  )

  SETLOCAL
    SET /P version=<"%ROOT_DIR%\bin\internal\flutter.version"

    REM Update flutter repo if needed.    
    PUSHD "%flutter_dir%"
      FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
      IF !version! NEQ !revision! (
        git reset --hard
        git clean -xdf
        git fetch --tags "%flutter_repo%" "!version!"
        git checkout FETCH_HEAD

        REM Invalidate the cache.
        IF EXIST "%cache_dir%" RMDIR /S /Q "%cache_dir%"
      )

      FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
      IF !version! NEQ !revision! (
        ECHO Error: Something went wrong while upgrading the Flutter SDK. 1>&2
        ECHO Remove the directory %flutter_dir% and try again.            1>&2
        EXIT /B 1
      )
    POPD

    CALL :apply_flutter_patches || EXIT /B

    REM Invalidate the flutter cache.  
    SET compilekey="%version%:"
    SET stamp_path=%flutter_dir%\bin\cache\flutter_tools.stamp
    IF NOT EXIST "%stamp_path%" GOTO do_flutter_version
    SET /P stamp=<"%stamp_path%"
    IF !compilekey! NEQ !stamp! GOTO do_flutter_version

    EXIT /B
    :do_flutter_version
      CALL "%flutter_exe%" >NUL || EXIT /B
  ENDLOCAL  
  EXIT /B

:apply_flutter_patches
  IF NOT EXIST "%flutter_patch_dir%" EXIT /B

  SETLOCAL ENABLEDELAYEDEXPANSION
    SET patch_revision=
    FOR /F %%r IN ('git --git-dir="%ROOT_DIR%\.git" --work-tree="%ROOT_DIR%" rev-parse HEAD:patches/flutter_tools 2^>NUL') DO SET patch_revision=%%r
    SET patch_state_changed=0
    IF DEFINED patch_revision (
      IF NOT EXIST "%flutter_patch_stamp_path%" (
        SET patch_state_changed=1
      ) ELSE (
        SET /P patch_stamp=<"%flutter_patch_stamp_path%"
        IF NOT "!patch_revision!"=="!patch_stamp!" (
          SET patch_state_changed=1
          PUSHD "%flutter_dir%"
            git reset --hard || EXIT /B 1
            SET /P flutter_version=<"%ROOT_DIR%\bin\internal\flutter.version"
            git checkout "!flutter_version!" >NUL || EXIT /B 1
          POPD
        )
      )
    )

    SET patch_applied=0
    PUSHD "%flutter_dir%"
      FOR %%p IN ("%flutter_patch_dir%\*.patch") DO (
        IF EXIST "%%~fp" (
          git apply --unidiff-zero --check "%%~fp" >NUL 2>NUL
          IF !ERRORLEVEL! EQU 0 (
            git apply --unidiff-zero --whitespace=nowarn "%%~fp" || EXIT /B 1
            SET patch_applied=1
          ) ELSE (
            git apply --unidiff-zero --reverse --check "%%~fp" >NUL 2>NUL
            IF !ERRORLEVEL! NEQ 0 (
              ECHO Error: Failed to apply Flutter patch: %%~fp 1>&2
              EXIT /B 1
            )
          )
        )
      )
    POPD

    IF "!patch_applied!"=="1" IF EXIST "%flutter_dir%\bin\cache\flutter_tools.stamp" DEL /F /Q "%flutter_dir%\bin\cache\flutter_tools.stamp"
    IF "!patch_state_changed!"=="1" IF EXIST "%flutter_dir%\bin\cache\flutter_tools.stamp" DEL /F /Q "%flutter_dir%\bin\cache\flutter_tools.stamp"
    IF DEFINED patch_revision (
      IF NOT EXIST "%flutter_dir%\bin\cache" MKDIR "%flutter_dir%\bin\cache"
      >"%flutter_patch_stamp_path%" ECHO !patch_revision!
    )
  ENDLOCAL
  EXIT /B

:update_flutter_tizen
  IF NOT EXIST "%cache_dir%" MKDIR "%cache_dir%"

  PUSHD "%ROOT_DIR%"
    FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
  POPD
  SET stamp_path=%ROOT_DIR%\bin\cache\flutter-tizen.stamp

  SETLOCAL
    IF NOT EXIST "%snapshot_path%" GOTO do_update_snapshot
    IF NOT EXIST "%stamp_path%" GOTO do_update_snapshot
    SET /P stamp_value=<"%stamp_path%"
    IF !revision! NEQ !stamp_value! GOTO do_update_snapshot
    SET pubspec_yaml_path=%ROOT_DIR%\pubspec.yaml
    SET pubspec_lock_path=%ROOT_DIR%\pubspec.lock
    FOR /F %%i IN ('DIR /B /O:D "%pubspec_yaml_path%" "%pubspec_lock_path%"') DO SET newer_file=%%i
    FOR %%i IN (%pubspec_yaml_path%) DO SET pubspec_yaml_timestamp=%%~ti
    FOR %%i IN (%pubspec_lock_path%) DO SET pubspec_lock_timestamp=%%~ti
    IF "%pubspec_yaml_timestamp%" == "%pubspec_lock_timestamp%" SET newer_file=""
    IF "%newer_file%" EQU "pubspec.yaml" GOTO do_update_snapshot
  ENDLOCAL
  EXIT /B

  :do_update_snapshot
    PUSHD "%ROOT_DIR%"
      ECHO Running pub upgrade...
      CALL "%flutter_exe%" pub upgrade || (
        ECHO Error: Unable to 'pub upgrade' flutter-tizen. 1>&2
        EXIT /B 1
      )

      ECHO Compiling flutter-tizen...
      CALL "%dart_exe%" --disable-dart-dev --no-enable-mirrors ^
                        --snapshot="%snapshot_path%" ^
                        --packages="%ROOT_DIR%\.dart_tool\package_config.json" ^
                        "%ROOT_DIR%\bin\flutter_tizen.dart" || (
        ECHO Error: Unable to create a flutter-tizen snapshot. 1>&2
        EXIT /B 1
      )

      >"%stamp_path%" ECHO %revision%
    POPD
    EXIT /B
  EXIT /B
