# Migrating to the native app model

This guide explains how to convert an existing C++ (`--tizen-language cpp`) or C# (`--tizen-language csharp`) app to the [native app model](native-app.md), where the `tizen` directory contains no source code and the app runs on the prebuilt runner.

## Before you start

The prebuilt runner does exactly what the default `runner.cc` and `App.cs` templates do: it starts the Flutter engine, registers plugins, and forwards app lifecycle events. Check your runner code first:

- If `tizen/src/runner.cc` or `tizen/App.cs` is unchanged from the template, you can migrate.
- If you only changed the Dart entrypoint (`SetDartEntrypoint` or `DartEntrypoint`), you can migrate. Use the `dart_entrypoint` metadata instead (see below).
- If you added other native code (for example, you changed the window size or transparency, the renderer type, the UI thread policy, or overrode lifecycle callbacks), keep using the C++ or C# app model.
- The native model doesn't support C# plugins. If your app depends on a plugin whose `pubspec.yaml` declares `fileName: *.csproj`, keep using the C# app model.
- Like C++ apps, native apps aren't supported on TV devices.

Commit or back up your project before migrating.

## Migrate a C++ app

1. Delete the runner sources and the native project files:

   ```sh
   cd tizen
   rm -rf inc src project_def.prop .exportMap Debug Release .cproject .sign crash-info
   ```

1. Keep `tizen-manifest.xml` and the `shared` directory as they are. The manifest of a C++ app already uses `type="capp"` and `exec="runner"`.

1. If `runner.cc` called `app.SetDartEntrypoint("myEntrypoint")`, add the entrypoint to the application element in `tizen-manifest.xml`:

   ```xml
   <metadata key="http://tizen.org/metadata/flutter_tizen/dart_entrypoint" value="myEntrypoint"/>
   ```

1. Replace the content of `tizen/.gitignore` with:

   ```
   flutter/
   .app.deps.json
   ```

## Migrate a C# app

1. Delete the C# sources, the project files, and the build outputs:

   ```sh
   cd tizen
   rm -rf App.cs *.csproj *.csproj.user bin obj tizen_dotnet_project.yaml
   ```

1. Update the application element in `tizen-manifest.xml`:

   - Change `exec="Runner.dll"` to `exec="runner"`.
   - Change `type="dotnet"` to `type="capp"`.
   - Add `hw-acceleration="on"` to a `ui-application` element.
   - Remove the .NET-specific metadata (`http://tizen.org/metadata/prefer_dotnet_aot` and `http://tizen.org/metadata/prefer_nuget_cache`).

   For example:

   ```diff
   -    <ui-application appid="com.example.my_app" exec="Runner.dll" type="dotnet" multiple="false" nodisplay="false" taskmanage="true">
   +    <ui-application appid="com.example.my_app" exec="runner" type="capp" multiple="false" nodisplay="false" taskmanage="true" hw-acceleration="on">
            <label>my_app</label>
            <icon>ic_launcher.png</icon>
   -        <metadata key="http://tizen.org/metadata/prefer_dotnet_aot" value="true"/>
   -        <metadata key="http://tizen.org/metadata/prefer_nuget_cache" value="true"/>
        </ui-application>
   ```

1. If `App.cs` set `DartEntrypoint`, add the `dart_entrypoint` metadata as described in [Migrate a C++ app](#migrate-a-c-app).

1. Replace the content of `tizen/.gitignore` with:

   ```
   flutter/
   .app.deps.json
   ```

## Migrate a multi app

C++ and C# multi apps have separate `tizen/ui` and `tizen/service` projects. A native multi app declares both applications in a single `tizen/tizen-manifest.xml` instead.

1. Move the UI app manifest and resources to the `tizen` directory:

   ```sh
   cd tizen
   mv ui/tizen-manifest.xml ui/shared .
   ```

1. Copy the `service-application` element from `service/tizen-manifest.xml` into `tizen/tizen-manifest.xml`, after the `ui-application` element. Also copy any privileges and features that only the service app declared.

1. Update both application elements as described in [Migrate a C++ app](#migrate-a-c-app) or [Migrate a C# app](#migrate-a-c-app-1). Give each application its own executable name, for example `exec="runner"` and `exec="runner_service"`.

1. Add the Dart entrypoint of the service app, which was set in `service/src/runner.cc` or `service/App.cs`:

   ```xml
   <service-application appid="com.example.my_multi_app_service" exec="runner_service" type="capp" ...>
       ...
       <metadata key="http://tizen.org/metadata/flutter_tizen/dart_entrypoint" value="serviceMain"/>
   </service-application>
   ```

1. Delete the `ui` and `service` directories, and update `tizen/.gitignore` as above.

To see a complete example, create a new app with `flutter-tizen create --tizen-language native --app-type multi` and compare its `tizen-manifest.xml`.

## Verify the migration

```sh
flutter-tizen clean
flutter-tizen build tpk
unzip -l build/tizen/tpk/*.tpk | grep bin/
```

The TPK contains the runner under the name of each `exec` attribute (for example `bin/runner` and `bin/runner_service`). Run the app with `flutter-tizen run` and check that it behaves as before.

## Reverting to a C++ app

To go back to the C++ app model, run the following in the project directory. The command adds the missing runner sources and project files without overwriting your manifest.

```sh
flutter-tizen create --platforms tizen --tizen-language cpp .
```

Then add the build output directories (`Debug/` and `Release/`) back to `tizen/.gitignore`.
