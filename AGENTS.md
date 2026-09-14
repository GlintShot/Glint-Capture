# Glint-Capture - Agent Instructions

Capture real Flutter UI into store-sized PNGs and `session.json`.

**You (the agent) are the intelligence.** Developers should not configure Capture API keys.

**Full workflow:** See `skills/glint/SKILL.md` in the GlintShot org for the complete multi-repo pipeline.

## Primary commands

- `glint init` - scaffold glint.yaml + test file + flutter_test_config.dart
- `glint discover [--write] [--max N]` - scan `lib/` for best marketing screens (no device)
- `glint capture [--auto]` - widget-test screenshots (`--auto` = discover + write + capture)

## Outputs

- PNG screenshots under device folders (glint_screenshots/{platform}/{device}/{screen}.png)
- `session.json` at output root (used by Glint-Web import)

## Rules

1. Use real app widgets/screens only - never invent UI
2. Keep rules deterministic and CI-friendly
3. Soft launch: prefer **one device** (pixel9) so `session.json` maps cleanly onto Web frames
4. Preserve screen order within that device
5. Always ship `test/flutter_test_config.dart` (Roboto + MaterialIcons) - never Ahem
6. Capture any Flutter widget tree (pages, dialogs, sheets); use `pump:` to open modals
7. Never invent UI pixels; never ask the user for LLM API keys for Capture

## Decision Flow

### Developer says: "take screenshots" / "capture store screenshots" / "generate screenshots"

Do NOT ask which screens. Use auto-discovery:

1. `glint discover --write` - scans lib/ for *Screen/*Page widgets, scores by marketing value, writes top 8
2. Review the discovered rules - verify they look like real user-facing screens
3. If any screen looks wrong (login, debug, empty, permission), edit the test file to remove it
4. `glint capture` - captures all rules at store sizes
5. Tell developer: output is in `glint_screenshots/`, import into Glint Web for templates

### Developer says: "capture HomeScreen, ProfileScreen, SettingsScreen"

Do NOT run discover. Write rules directly:

1. Create `test/glint_screenshots_test.dart` with only the specified screens
2. Use exact class names the developer gave
3. `glint capture`
4. Tell developer: output is in `glint_screenshots/`

### Developer says: "capture these screens but skip onboarding"

1. Run `glint discover --write` first (if no rules exist yet)
2. Edit `test/glint_screenshots_test.dart` - remove onboarding/splash rules
3. `glint capture`

### Developer says: "capture with multiple devices"

1. Write rules (via discover or manual) as above
2. Edit the devices list in the test file:
   ```dart
   devices: [
     GLINTDevice.pixel9,        // Play Store
     GLINTDevice.iphone16ProMax, // App Store 6.7"
     GLINTDevice.ipadPro129,     // App Store tablet
   ],
   ```
3. `glint capture`

### Developer says: "capture for Play Store only"

1. Write rules as above
2. Set devices: `[GLINTDevice.pixel9]` (default, soft launch)
3. `glint capture`

### Developer says: "capture for App Store only"

1. Write rules as above
2. Set devices: `[GLINTDevice.iphone16ProMax]`
3. `glint capture`

## Screen Quality Guide

When reviewing discovered screens, prefer:
- Home/feed screens with content (lists, cards, images)
- Feature screens with rich UI (grids, tabs, maps, players)
- Profile/settings screens with real data states
- Empty states with illustrations (not just text)

Reject:
- Login/signup/auth screens (not marketing material)
- Debug/test/scaffold screens
- Loading/error/permission screens
- Screens that are just `Center(child: Text('Hello'))`
- Dialog-only screens

## Device Presets

| Device | Logical Size | DPR | Store |
|--------|-------------|-----|-------|
| `pixel9` | 412×915 | 2.625 | Play Store (default) |
| `galaxy_s24` | 360×780 | 3.0 | Play Store |
| `iphone16ProMax` | 430×932 | 3.0 | App Store 6.7" |
| `iphone16Pro` | 393×852 | 3.0 | App Store 6.1" |
| `ipadPro129` | 1024×1366 | 2.0 | App Store tablet |
| `ipadPro11` | 834×1194 | 2.0 | App Store tablet |

Soft launch: one device (`pixel9`). Multi-device for full store coverage.
