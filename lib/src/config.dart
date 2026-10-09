import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'devices.dart';

/// Parsed glint.yaml configuration.
class GLINTConfig {
  GLINTConfig({
    required this.outputDir,
    required this.devices,
    required this.store,
    this.appName,
    this.tagline,
    this.locales = const [],
  });

  final String outputDir;
  final List<GLINTDevice> devices;
  final String store;

  /// App name surfaced in `session.json` → Glint-Web `{AppName}.zip`.
  final String? appName;

  /// One-line tagline surfaced in `session.json` → Glint View preview.
  final String? tagline;

  /// BCP-47 locales for per-locale capture / Fastlane folders.
  final List<String> locales;

  /// Load config from a glint.yaml file.
  static GLINTConfig load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Config not found', path);
    }
    return parse(file.readAsStringSync(), rootDir: p.dirname(p.absolute(path)));
  }

  /// Parse YAML content into a config.
  static GLINTConfig parse(String yaml, {String rootDir = '.'}) {
    final doc = loadYaml(yaml);
    if (doc is! Map) throw FormatException('Invalid glint.yaml');

    final outputDir = doc['output'] as String? ?? 'glint_screenshots';
    final store = _normalizeStore(doc['store'] as String? ?? 'play');
    final devices = _parseDevices(doc['devices'], rootDir: rootDir);

    return GLINTConfig(
      outputDir: outputDir,
      devices: devices,
      store: store,
      appName: doc['app_name'] as String?,
      tagline: doc['tagline'] as String?,
      locales: _parseLocales(doc['locales']),
    );
  }

  static List<GLINTDevice> _parseDevices(dynamic raw, {String rootDir = '.'}) {
    if (raw == null) return GLINTDevices.playStoreDefaults;

    if (raw is String) {
      return switch (raw) {
        'play_store' => GLINTDevices.playStoreDefaults,
        'app_store' => GLINTDevices.appStoreDefaults,
        'all' => GLINTDevices.allDefaults,
        'android' => GLINTDevices.resolve('android'),
        'ios' => GLINTDevices.resolve('ios'),
        'phones' => GLINTDevices.resolve('phones'),
        'tablets' => GLINTDevices.resolve('tablets'),
        _ => throw FormatException('Unknown device preset: $raw'),
      };
    }

    if (raw is List) {
      return raw.map((e) {
        if (e is! Map) throw FormatException('Invalid device entry');
        return GLINTDevice(
          name: e['name'] as String,
          size: Size(
            (e['width'] as num).toDouble(),
            (e['height'] as num).toDouble(),
          ),
          devicePixelRatio:
              (e['device_pixel_ratio'] as num?)?.toDouble() ?? 1.0,
          platform: _parsePlatform(e['platform'] as String?),
        );
      }).toList();
    }

    return GLINTDevices.playStoreDefaults;
  }

  static GLINTPlatform _parsePlatform(String? value) {
    return switch (value) {
      'ios' => GLINTPlatform.ios,
      _ => GLINTPlatform.android,
    };
  }

  /// Normalize legacy store shortcuts to canonical Glint-Web format.
  static String _normalizeStore(String raw) {
    return switch (raw) {
      'play' => 'play/phone',
      'android' => 'play/phone',
      'ios' => 'ios/iphone',
      'ios-tablet' => 'ios/ipad',
      _ => raw, // already canonical: play/phone, ios/iphone, etc.
    };
  }

  static List<String> _parseLocales(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String) return [raw];
    if (raw is List) return [for (final e in raw) e as String];
    return const [];
  }

  /// Find glint.yaml by walking up from [startDir].
  static String? findConfig([String? startDir]) {
    var dir = Directory(startDir ?? Directory.current.path);
    for (var i = 0; i < 10; i++) {
      final file = File(p.join(dir.path, 'glint.yaml'));
      if (file.existsSync()) return file.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
