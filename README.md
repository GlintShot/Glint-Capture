# Glint Capture

Device-free Flutter screenshot capture for Play Store and App Store assets.

Part of the [Glint](https://github.com/GlintShot) ecosystem. Soft-launch path: **Capture → Web → View**.

## Install

**Git tag (soft launch - until pub.dev):**

```yaml
dev_dependencies:
  glint_capture:
    git:
      url: https://github.com/GlintShot/Glint-Capture.git
      ref: v0.1.0
```

**Monorepo path:**

```yaml
dev_dependencies:
  glint_capture:
    path: ../Glint-Capture
```

Then activate the CLI:

```bash
dart pub global activate --source git https://github.com/GlintShot/Glint-Capture.git
# or from a checkout: dart pub global activate --source path .
```

```bash
glint init
glint capture              # manual rules
glint capture --auto       # scan lib/ for screens, write rules, capture
# Or ask Cursor / Copilot: "capture store screenshots for this app"
```

**pub.dev:** package name `glint_capture`. After first publish:

```yaml
dev_dependencies:
  glint_capture: ^0.1.0
```

```bash
dart pub global activate glint_capture
```

## Features

- Screenshots from Flutter widget tests - no emulator required
- **Manual rules** or **auto discover** (`glint discover` / `glint capture --auto`) - finds real `*Screen`/`*Page` widgets and writes builders
- Works with **agentic IDEs** (Cursor / Copilot / Claude) - the agent crawls code and captures; no Glint API keys
- Any widget tree you build: pages, dialogs, bottom sheets, drawers, custom painters
- Full device pixel size (logical × DPR) with Roboto + MaterialIcons
- Declarative `GLINTRule` API + template flows
- Six curated store devices + `session.json` for Glint Web

## What you can capture

| UI | How |
|----|-----|
| Pages / `Scaffold` | `builder: (_) => const HomeScreen()` |
| Dialog / bottom sheet | Compose in the tree, **or** open with `pump:` (tap then settle) |
| Drawer / snackbar / overlay | Same - build it or trigger it in `pump` |
| Custom fonts | Declare in host `pubspec` → loaded via `flutter_test_config.dart` |
| Asset images | Yes if listed in `pubspec` |

**Not** a live-device recorder: it captures the Flutter widget tree in tests (same pixels as your UI), not Android/iOS system chrome, platform views, or unreproducible network images without mocks.

```dart
// Dialog composed in the tree
GLINTRule.screen(
  name: 'confirm',
  builder: (context) => Stack(
    fit: StackFit.expand,
    children: [
      const HomeScreen(),
      ModalBarrier(color: Colors.black54, dismissible: false),
      Center(child: AlertDialog(
        title: Text('Delete?'),
        actions: [TextButton(onPressed: () {}, child: Text('Cancel'))],
      )),
    ],
  ),
),

// Or open a real sheet after pump
GLINTRule.screen(
  name: 'filters',
  builder: (context) => const HomeScreen(),
  pump: (tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  },
),
```

Require `test/flutter_test_config.dart` (`glint init` creates it) so text is Roboto, not Ahem.

## Quick example

```dart
import 'package:flutter/material.dart';
import 'package:glint_capture/glint_capture.dart';

void main() {
  glintScreenshots(
    appName: 'MyApp',
    tagline: 'Edit photos like a pro',
    devices: GLINTDevices.playStoreDefaults,
    rules: [
      GLINTRule.screen(
        name: 'home',
        builder: (context) => const Scaffold(
          body: Center(child: Text('Home Screen')),
        ),
      ),
    ],
  );
}
```

```bash
glint init && glint capture
# or: flutter test test/glint_screenshots_test.dart
```

Import the output folder into **Glint Web** → Templates → Export → Copy for Glint View.

**Tip:** Soft launch with **one device** (e.g. `pixel9`) so `session.json` maps cleanly onto Web frames. Multi-device captures still write all PNGs; session lists the primary device only.

## Device presets

Six curated devices only:

| Preset | Logical size | DPR | Store |
|--------|--------------|-----|-------|
| `pixel9` | 412×915 | 2.625 | Play (default) |
| `galaxy_s24` | 360×780 | 3.0 | Play |
| `iphone16_pro_max` | 430×932 | 3.0 | App Store 6.7" |
| `iphone16_pro` | 393×852 | 3.0 | App Store |
| `ipad_pro_129` | 1024×1366 | 2.0 | App Store tablet |
| `ipad_pro_11` | 834×1194 | 2.0 | App Store tablet |

Lists: `GLINTDevices.premium` (= all), `.playStoreDefaults`, `.appStoreDefaults`. Soft launch: one device (`pixel9`).

## CI

```yaml
- run: dart run glint_capture capture
- uses: actions/upload-artifact@v4
  with:
    name: glint-screenshots
    path: glint_screenshots/
```

## License

MIT

---

<div align="center">

<a href="https://github.com/darkmintis">
  <img src="https://img.shields.io/badge/follow-%40Darkmintis-1DA1F2?style=social&logo=github" alt="Follow @Darkmintis"/>
</a>

</div>
