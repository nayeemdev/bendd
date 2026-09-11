# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Bendd is a free macOS menu bar app that renders the desktop tilting/bending as the built-in display's lid closes, using the lid angle sensor, ScreenCaptureKit, and Metal. `plan.md` is the phased build plan (Phase 0 through Phase 6 are done, except Developer ID signing/notarization: Apple restricts creating a Developer ID Application certificate to an account's Account Holder role, and that access isn't available for this project's Apple Developer Program enrollment yet. Releases ship ad-hoc signed until that's resolved). Check it before assuming a feature is unbuilt.

## Repository layout

- `Bendd/` — the real product, a Swift Package (not an Xcode project).
- `Spikes/` — throwaway Phase 0 feasibility scripts (lid sensor read, ScreenCaptureKit capture, Metal perspective render). Not built on or imported by `Bendd/`; kept only as a record of what Phase 0 proved.

## Commands

All commands run from `Bendd/`.

```sh
swift build -c release          # build
swift run Bendd                 # run unbundled, from a terminal
./Scripts/build-app.sh          # assemble dist/Bendd.app (ad-hoc signed by default) with a real Info.plist and icon
./Scripts/make-dmg.sh           # package dist/Bendd.app into dist/Bendd-<version>.dmg (run build-app.sh first)
./Scripts/notarize.sh           # notarize and staple the app and DMG (run build-app.sh with BENDD_SIGNING_IDENTITY set first)
```

There is no test target. There's no linter configured.

Notarized release builds require `BENDD_SIGNING_IDENTITY` set to a Developer ID Application identity (`security find-identity -v -p codesigning`) before running `build-app.sh`, and a `xcrun notarytool store-credentials` keychain profile (default name `bendd-notary`, overridable via `BENDD_NOTARY_PROFILE`) before running `notarize.sh`. Without `BENDD_SIGNING_IDENTITY` set, `build-app.sh` falls back to ad-hoc signing for local testing.

Debug-only environment variables (checked at launch, not part of the shipped UI):
- `BENDD_DEBUG_ANGLE=<degrees>` — overrides the lid angle sensor reading, for testing the bend without physically moving the lid.
- `BENDD_DEBUG_SHOW_POPOVER=1` — auto-opens the settings popover shortly after launch via `StatusItemController.simulateClick()`.

Screen Recording permission is required for the capture path to work; it's tied to whatever process is "responsible" for launching Bendd (a terminal, or the app bundle once it has a stable bundle identifier), and once denied for a given identity it must be re-granted in System Settings > Privacy & Security > Screen Recording — Bendd cannot re-request it itself, it only surfaces a banner with a deep link.

## Architecture

Two targets: `BenddKit` (engine, no AppKit/SwiftUI dependency) and `Bendd` (the executable — AppKit, SwiftUI, and all UI/system-integration code). This split is deliberate: `BenddKit` should stay testable/reusable without pulling in app-shell concerns.

**BenddKit**
- `Sensing/LidAngleSensor.swift` — reads the lid angle via a private IOKit HID interface (vendor `0x05AC`, product `0x8104`, usage page `0x0020`, usage `0x008A`, feature report ID 1; raw report bytes decode directly as degrees, no scaling). Polls on a `Timer`, not push-based. Polls at two rates via `setTrackingActive(_:)` — fast (60 Hz) while the bend is visible, coarse (10 Hz) otherwise — this is the single biggest idle-CPU lever in the app; don't poll at a fixed fast rate regardless of state. Supports a `debugAngleOverride` (see `BENDD_DEBUG_ANGLE` above) that also backs the settings UI's live drag-to-preview slider.
- `Capture/DesktopCapture.swift` — wraps `SCStream`, always targets the display where `CGDisplayIsBuiltin` is true (never the main/active display, so an external monitor never gets captured or breaks this). Builds `MTLTexture` directly from each frame's `IOSurface` (zero-copy) rather than copying pixel data.
- `Rendering/` — `BendTransform` (pure math: lid angle → bend fraction/tilt degrees/4x4 matrix, given a caller-supplied clear angle and max tilt, not hardcoded constants), `BendRenderer` (`MTKViewDelegate`; per frame, Gaussian-blurs the captured texture via `MPSImageGaussianBlur` into a cached scratch texture sized to match, then renders a hinge-rotated quad textured with it, with shading/desaturation uniforms baked in from the current `BendStyle` and `BendConfiguration`), `BendStyle` (Silk/Shade/Frost presets), `Shaders.metal` (compiled from source string at runtime via `device.makeLibrary(source:)`, not as a precompiled `.metallib` — SwiftPM doesn't compile `.metal` files for a plain `swift build`, so the shader source ships as a bundled resource and is read as text).
- `BendConfiguration.swift` — the one Codable settings struct (style, clear angle, perspective depth, blur/shadow multipliers, effect/sound toggles, launch-at-login). Persisted by `Bendd`'s `SettingsStore`, not by `BenddKit` itself.
- `BendController.swift` — the coordinator. Owns the sensor, capture, and renderer; decides "should the effect be active right now" (`isEffectEnabled && lid angle below clear angle`) and starts/stops `DesktopCapture` and sensor fast-polling on that transition. Never throws or crashes on missing hardware or a denied permission — a missing sensor degrades to `isSensorAvailable = false` (surfaced in the UI, not a crash), and a capture failure calls `onCaptureError` instead of throwing past the caller.

**Bendd (app shell)**
- `AppDelegate.swift` — wires `BendController` to `SettingsStore` via Combine (`store.$configuration` → `controller.configuration`), to `OverlayWindowController` (`controller.onActiveChange` → show/hide), and to system notifications (sleep/wake stops capture and hides the overlay so nothing lingers as a stuck frame; `didChangeScreenParametersNotification` re-anchors the overlay to the built-in screen's current frame).
- `OverlayWindowController.swift` — the full-screen, borderless, click-through, `.screenSaver`-level window that hosts the `MTKView`. **Important gotcha**: a `.screenSaver`-level window suppresses the system menu bar just by existing on screen, even fully transparent and paused — so `setActive(false)` must `orderOut` the window, not just pause the `MTKView`. Don't "simplify" this back to just toggling `isPaused`.
- `StatusItemController.swift` / `SettingsView.swift` / `SettingsStore.swift` — the menu bar item, its SwiftUI settings popover, and UserDefaults-backed persistence (JSON-encoded `BendConfiguration` under key `com.bendd.configuration`). The popover's `NSHostingController` is built fresh on each show and torn down in `popoverDidClose` — the mini live-preview view runs a 30 Hz timer, so keeping it alive while hidden was a real (fixed) idle-CPU regression.
- `OnboardingWindowController.swift` / `OnboardingView.swift` — first-launch explanation + Screen Recording grant prompt, gated on a UserDefaults flag so it only shows once.
- `MenuBarIcon.swift` / `Scripts/generate-icon.swift` — the menu bar glyph and the full app icon are both drawn programmatically (Core Graphics paths), not imported image assets.

## Known constraints worth remembering

- `applicationShouldTerminateAfterLastWindowClosed` must return `false`. This is a menu-bar-only (`.accessory` activation policy, no Dock icon) app with no main window; returning `true` here means the app silently quits the moment the overlay or the settings popover closes.
- Only tested on one machine (Apple Silicon MacBook Air, macOS 26). The lid angle sensor's vendor/product/usage IDs came from reverse-engineering by others (see `plan.md` Phase 0) and aren't guaranteed identical across every Mac model with the sensor.
