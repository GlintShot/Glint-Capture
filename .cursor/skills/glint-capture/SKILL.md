---
name: glint-capture
description: Set up Glint Capture and produce real Flutter store screenshots (session.json).
---

# Glint Capture (agent)

You are the AI. Developers do **not** paste API keys into Glint. You discover screens, write real rules, and run capture.

## Install

```yaml
dev_dependencies:
  glint_capture:
    git:
      url: https://github.com/GlintShot/Glint-Capture.git
      ref: v0.1.0
```

```bash
dart pub get
dart pub global activate --source git https://github.com/GlintShot/Glint-Capture.git
glint init
```

## How you capture (agent)

1. Scan the app `lib/` for real screens (`*Screen` / `*Page`) - or run `glint discover --write` / `glint capture --auto`.
2. Ensure `test/glint_screenshots_test.dart` uses **real** app widgets (fix generated builders if needed).
3. Soft launch: **pixel9** only.
4. Run `glint capture` (or `glint capture --auto`).
5. Confirm `glint_screenshots/session.json` + PNGs.

## Manual (developer)

They edit `test/glint_screenshots_test.dart` themselves → `glint capture`.

## Do not

- Ask the developer for OpenAI/Anthropic API keys for Capture
- Fabricate UI bitmaps
- Leave placeholder `Text('Home Screen')` scaffolds when real screens exist

## Next

Import into Glint Web or MCP `glint_export`. Docs: `Glint-Docs/guides/golden-path.md`.
