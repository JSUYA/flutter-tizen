# support_ffi_plugin_sample

A minimal FFI-only Tizen plugin sample for flutter-tizen.

The plugin declares `ffiPlugin: true` without `pluginClass` or
`dartPluginClass`. This exercises flutter-tizen's plugin parser support for
FFI-only Tizen plugins.

To try the sample app:

```sh
cd packages/support_ffi_plugin_sample/example
../../../bin/flutter-tizen pub get
../../../bin/flutter-tizen build tpk --debug
```

The generated Tizen plugin registrant should not contain a registration call
for this plugin, while `tizen/.app.deps.json` should list
`support_ffi_plugin_sample`.
