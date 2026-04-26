import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const _AssetPlatformExampleApp());
}

class _AssetPlatformExampleApp extends StatelessWidget {
  const _AssetPlatformExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tizen asset platform',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0077c8)),
      ),
      home: const _AssetPlatformHome(),
    );
  }
}

class _AssetPlatformHome extends StatefulWidget {
  const _AssetPlatformHome();

  @override
  State<_AssetPlatformHome> createState() => _AssetPlatformHomeState();
}

class _AssetPlatformHomeState extends State<_AssetPlatformHome> {
  late final Future<List<_AssetLoadResult>> _assets = _loadAssets();

  Future<List<_AssetLoadResult>> _loadAssets() async {
    return <_AssetLoadResult>[
      await _loadAsset('Common', 'assets/common.txt'),
      await _loadAsset('Tizen only', 'assets/tizen_only.txt'),
      await _loadAsset('Android only', 'assets/android_only.txt'),
      await _loadAsset('Linux only', 'assets/linux_only.txt'),
    ];
  }

  Future<_AssetLoadResult> _loadAsset(String label, String path) async {
    try {
      final String value = await rootBundle.loadString(path);
      return _AssetLoadResult(label, path, value.trim(), true);
    } on FlutterError {
      return _AssetLoadResult(label, path, 'Not bundled', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tizen asset platform')),
      body: FutureBuilder<List<_AssetLoadResult>>(
        future: _assets,
        builder: (BuildContext context, AsyncSnapshot<List<_AssetLoadResult>> snapshot) {
          final List<_AssetLoadResult> assets = snapshot.data ?? <_AssetLoadResult>[];
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (BuildContext context, int index) {
              final _AssetLoadResult asset = assets[index];
              return ListTile(
                leading: Icon(
                  asset.loaded ? Icons.check_circle : Icons.remove_circle_outline,
                  color: asset.loaded ? Colors.green : Colors.grey,
                ),
                title: Text(asset.label),
                subtitle: Text(asset.path),
                trailing: Text(asset.value),
              );
            },
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
            itemCount: assets.length,
          );
        },
      ),
    );
  }
}

class _AssetLoadResult {
  const _AssetLoadResult(this.label, this.path, this.value, this.loaded);

  final String label;
  final String path;
  final String value;
  final bool loaded;
}
