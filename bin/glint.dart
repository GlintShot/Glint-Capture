#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:glint_capture/src/discover/discover.dart';
import 'package:glint_capture/src/session.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// CLI for Glint - generates store-ready screenshots.
///
/// Usage:
///   glint init
///   glint discover [--write] [--max N]
///   glint capture [--auto]
///
/// Agents (Cursor / Copilot / Claude): discover screens, write real rules,
/// run capture - no developer API keys required.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printHelp();
    return;
  }

  final command = args.first;
  final rest = args.skip(1).toList();

  switch (command) {
    case 'init':
      await _init();
    case 'discover':
      await _discover(rest);
    case 'capture':
      // --auto / --ai / --discover: scan lib/ and write rules, then capture
      final auto = rest.any((a) => a == '--auto' || a == '--ai' || a == '--discover');
      if (auto) {
        await _discover([
          '--write',
          ...rest.where((a) => a != '--auto' && a != '--ai' && a != '--discover'),
        ]);
      }
      await _capture();
    case '-h':
    case '--help':
    case 'help':
      _printHelp();
    default:
      print('Unknown command: $command');
      print('Run: glint help');
      exit(1);
  }
}

Future<void> _init() async {
  final configPath = 'glint.yaml';
  final screensPath = p.join('test', 'glint_screenshots_test.dart');
  final fontConfigPath = p.join('test', 'flutter_test_config.dart');

  if (File(configPath).existsSync()) {
    print('glint.yaml already exists. Skipping.');
  } else {
    await File(configPath).writeAsString(_defaultConfig);
    print('Created glint.yaml');
  }

  if (File(screensPath).existsSync()) {
    print('$screensPath already exists. Skipping.');
  } else {
    await Directory(p.dirname(screensPath)).create(recursive: true);
    await File(screensPath).writeAsString(_defaultScreens);
    print('Created $screensPath');
  }

  if (File(fontConfigPath).existsSync()) {
    print('$fontConfigPath already exists. Skipping.');
  } else {
    await Directory(p.dirname(fontConfigPath)).create(recursive: true);
    await File(fontConfigPath).writeAsString(_defaultFontConfig);
    print('Created $fontConfigPath');
  }

  print('''
Done! Next steps (pick one):
  Manual:  edit $screensPath with your real screens → glint capture
  Auto:    glint capture --auto   (scans lib/ for *Screen/*Page, writes rules, captures)
  Agent:   ask Cursor / Copilot to capture store screenshots for this app
''');
}

Future<void> _discover(List<String> args) async {
  final write = args.contains('--write') || args.contains('-w');
  var maxKeep = 8;
  for (var i = 0; i < args.length; i++) {
    if ((args[i] == '--max' || args[i] == '--max-screens') && i + 1 < args.length) {
      maxKeep = int.tryParse(args[i + 1]) ?? maxKeep;
    }
  }

  final root = Directory.current.path;

  print('Glint discover');
  print('  Root: $root');
  print('  Mode: scan lib/ for *Screen / *Page widgets');

  final scanner = ScreenScanner(projectRoot: root);
  List<DiscoveredScreen> found;
  try {
    found = await scanner.scan();
  } catch (e) {
    print('Error: $e');
    exit(1);
  }

  if (found.isEmpty) {
    print('No *Screen / *Page widgets found under lib/.');
    print('Name screens like HomeScreen, write rules manually, or ask your agent.');
    exit(1);
  }

  print('  Found: ${found.length} candidate(s)');
  final picks = found.take(maxKeep).toList();

  for (final s in picks) {
    print(
      '  • ${s.name.padRight(16)} ${s.className}  '
      'score=${s.score.toStringAsFixed(2)}  (${s.reason})',
    );
  }

  if (!write) {
    print('\nDry run. Re-run with --write to update test/glint_screenshots_test.dart');
    print('Or: glint capture --auto');
    return;
  }

  final codegen = ScreensTestCodegen(
    projectRoot: root,
  );
  final file = await codegen.mergeOrWrite(picks);
  print('\nWrote ${p.relative(file.path)}');
  print('Next: glint capture  (or ask your agent to polish rules + capture)');
}

Future<void> _capture() async {
  final configPath = _findConfig();
  if (configPath == null) {
    print('Error: No glint.yaml found. Run: glint init');
    exit(1);
  }

  final yaml = loadYaml(File(configPath).readAsStringSync());
  final store = _normalizeStore(yaml['store'] as String? ?? 'play');
  final outputDir = yaml['output'] as String? ?? 'glint_screenshots';
  final devicesRaw = yaml['devices'];

  List<String> deviceNames;
  if (devicesRaw is String) {
    deviceNames = [devicesRaw];
  } else if (devicesRaw is List) {
    deviceNames = devicesRaw.map((d) => d['name'] as String).toList();
  } else {
    deviceNames = ['play_store'];
  }

  print('Glint');
  print('  Config:  $configPath');
  print('  Store:   $store');
  print('  Devices: ${deviceNames.join(', ')}');

  final testFile = _findTestFile();
  if (testFile == null) {
    print('\nError: No screens file found. Run: glint init  or  glint discover --write');
    exit(1);
  }

  print('  Screens: ${p.relative(testFile)}');
  print('\nCapturing...');

  // Ensure dependencies are resolved before running tests.
  final pubGet = await Process.run('flutter', ['pub', 'get'], runInShell: true);
  if (pubGet.exitCode != 0) {
    stdout.write(pubGet.stdout);
    stderr.write(pubGet.stderr);
    print('\nWarning: flutter pub get failed, attempting capture anyway');
  }

  final result = await Process.run('flutter', [
    'test',
    testFile,
    '--no-pub',
  ], runInShell: true);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('\nError: flutter test failed (exit ${result.exitCode})');
    exit(result.exitCode);
  }

  var count = 0;
  final outputDirObj = Directory(outputDir);
  if (outputDirObj.existsSync()) {
    for (final entity in outputDirObj.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.png')) count++;
    }
  }

  if (count > 0 && outputDirObj.existsSync()) {
    try {
      final session = GLINTSession.fromDirectory(
        outputDir: outputDir,
        store: store,
      );
      await session.write(outputDir);
      print('Wrote session.json (${session.screens.length} screen path(s)).');
    } catch (e) {
      print('Warning: could not write session.json: $e');
    }
  }

  print('\nDone! Generated $count screenshot(s).');
  print('Output: ${p.normalize(outputDir)}/');
  print('Next: import into Glint Web → template → polish → export ZIP.');
}

String? _findConfig() {
  for (final path in ['glint.yaml', 'glint.yml']) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

String? _findTestFile() {
  for (final path in [
    'test/glint_screenshots_test.dart',
    'test/screenshots_test.dart',
    'test/glint_test.dart',
  ]) {
    if (File(path).existsSync()) return path;
  }

  final testDir = Directory('test');
  if (testDir.existsSync()) {
    for (final file in testDir.listSync().whereType<File>()) {
      if (file.path.endsWith('.dart')) {
        final content = file.readAsStringSync();
        if (content.contains('glintScreenshots')) return file.path;
      }
    }
  }

  return null;
}

void _printHelp() {
  print('''
Glint Capture - device-free Flutter store screenshots

Usage:
  glint <command>

Commands:
  init                      Create glint.yaml + screens file + font config
  discover [--write] [--max N]
                            Scan lib/ for *Screen/*Page and optionally write rules
  capture [--auto]          Run flutter test screenshots
                            --auto = discover + write rules, then capture
  help                      Show this help

Two ways for developers:
  Manual   Edit test/glint_screenshots_test.dart → glint capture
  Auto     glint capture --auto

Agentic IDEs (Cursor / Copilot / Claude Code):
  Ask the agent to capture store screenshots - it uses discover/rules + capture.
  No API keys to configure in Glint.

Then: import glint_screenshots/ into Glint Web → templates → polish → ZIP.
''');
}

/// Normalize legacy store shortcuts to canonical Glint-Web format.
String _normalizeStore(String raw) {
  return switch (raw) {
    'play' => 'play/phone',
    'android' => 'play/phone',
    'ios' => 'ios/iphone',
    'ios-tablet' => 'ios/ipad',
    _ => raw,
  };
}

const _defaultConfig = '''# Glint configuration
# Docs: https://github.com/GlintShot/Glint-Capture
#
# Soft launch: capture ONE device for clean Glint Web frame mapping.
# Add more devices later if you need size variants on disk.

store: play/phone  # play/phone | ios/iphone | ios/ipad

# Presets (multi-device - session.json still picks a primary for Web):
# devices: play_store
# devices: app_store

# Soft-launch default - Pixel 9 (premium Play phone):
devices:
  - name: pixel9
    width: 412
    height: 915
    device_pixel_ratio: 2.625
    platform: android
''';

const _defaultScreens = '''import 'package:flutter/material.dart';
import 'package:glint_capture/glint_capture.dart';

/// Return real app screens (Scaffold / page widgets), not a nested MaterialApp.
/// Soft launch: one device keeps session.json ordered for Glint Web frames.
///
/// Dialogs / bottom sheets: compose them in the tree, or open them in [pump].
///
/// Manual: edit rules below → glint capture
/// Auto:   glint capture --auto   (discovers *Screen/*Page in lib/)
/// Agent:  ask Cursor / Copilot to set up and capture screenshots
void main() {
  glintScreenshots(
    devices: [GLINTDevice.pixel9],
    rules: [
      GLINTRule.screen(
        name: 'home',
        builder: (context) => const Scaffold(
          body: Center(child: Text('Home Screen')),
        ),
      ),
      // Add more screens, dialogs, or sheets here...
    ],
  );
}
''';

const _defaultFontConfig = '''import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads real fonts before tests so captures are not Ahem blocks.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final robotoLoader = FontLoader('Roboto');
  for (final asset in [
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Thin.ttf',
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Light.ttf',
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Regular.ttf',
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Medium.ttf',
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Bold.ttf',
    'packages/glint_capture/assets/fonts/Roboto/Roboto-Black.ttf',
  ]) {
    robotoLoader.addFont(rootBundle.load(asset));
  }
  await robotoLoader.load();

  try {
    final iconsLoader = FontLoader('MaterialIcons');
    iconsLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconsLoader.load();
  } catch (_) {}

  try {
    final manifestString = await rootBundle.loadString('FontManifest.json');
    final manifest = json.decode(manifestString) as List<dynamic>;

    for (final entry in manifest) {
      final family = entry['family'] as String;
      final fonts = entry['fonts'] as List<dynamic>;
      if (family == 'Roboto' ||
          family == 'packages/glint_capture/Roboto' ||
          family == 'MaterialIcons') {
        continue;
      }
      final loader = FontLoader(family);
      for (final fontAsset in fonts) {
        loader.addFont(rootBundle.load(fontAsset['asset'] as String));
      }
      await loader.load();
    }
  } catch (_) {}

  await testMain();
}
''';
