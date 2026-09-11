# Bendd, macOS App Build Plan

A step by step roadmap for building Bendd, a free "your desktop bends as the lid closes" app, from a rough spike to a polished, notarized release.

---

## Phase 0. Feasibility Spike (1-3 days)

Goal: prove the two riskiest technical pieces work on your hardware before designing anything else.

- [x] Confirm your Mac is Apple Silicon with a physical lid angle sensor (recent MacBook Air/Pro).
- [x] Find and run an open source lid angle sensor reference (e.g. the "LidAngleSensor" project on GitHub) as a standalone command line tool. Confirm you get a live angle value (0 to 180 degrees) while opening/closing the lid.
- [x] Write a throwaway script using `CGRequestScreenCaptureAccess()` plus `ScreenCaptureKit` to grab a single screenshot of the desktop.
- [x] Write a minimal Metal view that renders a static image with a perspective transform, just to confirm the Metal pipeline compiles and displays.

Exit criteria: you can print a live angle number in Terminal, and you can render a texture in a Metal backed `NSView`. If either fails, stop and debug before proceeding, everything else depends on these two capabilities.

---

## Phase 1. MVP: "It Bends" (1-2 weeks)

Goal: a single hacky build that visibly bends the screen as the lid closes. Ugly is fine. No settings, no menu bar, no packaging.

- [x] Wrap the lid angle sensor code into a small class that publishes angle updates (Combine `@Published` or a delegate callback).
- [x] Set up an `SCStream` (ScreenCaptureKit) that continuously captures the desktop as a texture, not just a single shot.
- [x] Create a full screen, borderless, transparent `NSWindow` at a high window level (`.screenSaver` or similar) that a normal window can't cover.
- [x] Render the captured desktop texture in a `CAMetalLayer`/`MTKView` inside that window.
- [x] Apply a simple 3D perspective transform (rotate around the bottom edge) driven directly by the live angle value, no easing, no blur yet.
- [x] Hardcode Screen Recording permission prompt at launch.

Exit criteria: close your laptop lid partway and see the live desktop tilt in real time, however crude. This is your proof of concept demo video moment.

---

## Phase 2. Visual Quality Pass (1-2 weeks)

Goal: make the bend actually look good, this is most of the product's perceived value.

- [x] Add a Gaussian blur pass (Metal Performance Shaders `MPSImageGaussianBlur`) that scales with angle, more blur as the lid closes further.
- [x] Add a shading/vignette layer that darkens the tilted plane proportionally to angle, to sell the "closing" depth cue.
- [x] Smooth the raw sensor input (basic low pass filter or spring/damping) so the motion doesn't feel jittery.
- [x] Implement three visual styles as parameter presets (e.g. Silk = more blur/less shadow, Shade = more shadow/less blur, Frost = both plus slight desaturation).
- [x] Add a "clear angle" threshold, above this angle the desktop renders fully normal (no overlay), so there's zero cost when the lid is open.
- [x] Profile GPU/CPU usage, capture plus blur running continuously must stay cheap (aim for low single digit percent CPU, minimal GPU wake).

Exit criteria: side by side, the effect is visually comparable to reference demo quality. Battery/CPU impact is negligible when the lid is open and idle.

---

## Phase 3. App Shell (1 week)

Goal: turn the prototype into something that behaves like a real Mac utility.

- [x] Convert to a proper menu bar only app (`NSStatusItem`, `LSUIElement = true` in Info.plist so it has no Dock icon). (No Dock icon via `.accessory` activation policy for now; `LSUIElement` in Info.plist lands with the app bundle in Phase 6.)
- [x] Build a SwiftUI settings popover: live mini preview, sliders for perspective depth / blur amount / shadow strength, style picker (Silk/Shade/Frost), lid clear angle slider.
- [x] Add manual drag to preview, let the user drag an on screen angle slider to test the effect without physically closing the lid.
- [x] Persist settings with `UserDefaults` or a small Codable settings struct.
- [x] Add pause/resume, click the menu bar icon or press Esc to toggle the effect off. (Right-click the icon to toggle instantly; left-click opens settings with the same toggle and Esc closes the popover.)
- [x] Add "Launch at Login" toggle (`SMAppService` on modern macOS).

Exit criteria: a friend could open the app, tweak sliders, see a live preview, and have it persist across relaunch, without you explaining anything.

---

## Phase 4. Robustness and Permissions Hardening (3-5 days)

Goal: make it survive real world conditions, not just your dev machine.

- [x] Handle Screen Recording permission gracefully: detect if it's not granted, show a clear prompt/deep link to System Settings, and don't crash.
- [x] Handle external displays: effect should only apply to the built in display, and should not break when an external monitor is connected/disconnected mid session. (Capture always targets the built-in `SCDisplay` specifically; the overlay re-anchors its frame on any screen configuration change.)
- [x] Handle sleep/wake and lid close to actual sleep transition (macOS may sleep the Mac at full closure, make sure the overlay doesn't linger as a stuck frame). (Overlay force-hides and capture stops on `willSleep`/`screensDidSleep`; normal polling picks the real state back up on wake.)
- [x] Handle multiple Spaces / full screen apps / Mission Control, decide and test whether the overlay should appear over full screen apps. (Decision: yes, it should, the whole physical display bends regardless of what's on it, so the overlay joins all Spaces via `.canJoinAllSpaces`.)
- [x] Add crash safety, if the sensor read or capture stream throws, fail silently to "no effect" rather than crashing or freezing the display. (Missing sensor degrades to a disabled, explained state in settings instead of a crash; capture failures surface as a dismissable banner instead of taking down the app.)
- [ ] Test on at least 2 different MacBook models/macOS versions if possible (sensor behavior can vary). (Only one machine, this M5 MacBook Air on macOS 26.6, was available to test against during this build. Worth doing before a wider release.)

Exit criteria: you can't break it by unplugging monitors, sleeping, waking, or force quitting mid animation.

---

## Phase 5. Sound and Final Polish (2-4 days)

Goal: the small details that make it feel finished.

- [x] Add a soft click/chime sound on full open (crossing the clear angle threshold), using `NSSound` or `AVAudioPlayer`.
- [x] Add a General settings toggle to disable sound.
- [x] Design a proper menu bar icon (template image, light/dark mode aware) and app icon. (Menu bar icon is a custom drawn "tilting laptop" template glyph. The Finder/Dock app icon asset is deferred to Phase 6, where the real .app bundle it belongs in gets created.)
- [x] Write onboarding: first launch screen explaining Screen Recording permission and what the app does, with a "grant permission" button.
- [x] Add an About menu item (version number, contact email, link to project page). (Shown as a footer in the settings popover instead of a separate menu item, since the app has no traditional menu bar menu; links to the GitHub repo rather than a support email, since there isn't one yet.)

Exit criteria: it feels like a finished indie app, not a script someone ran from Xcode.

---

## Phase 6. Packaging and Free Distribution (2-4 days)

Goal: get a distributable, trustworthy build that anyone can download and run for free.

- [x] Enroll in the Apple Developer Program if needed (still required for Developer ID signing/notarization, even for free apps). (Done, but Developer ID Application certificate creation is restricted to an account's Account Holder role specifically, confirmed directly on developer.apple.com's own certificate-creation page, not just an Xcode UI gap, and that access isn't available for this enrollment yet.)
- [ ] Set up code signing with a Developer ID Application certificate. (`Scripts/build-app.sh` ad-hoc signs by default; set `BENDD_SIGNING_IDENTITY` to a `Developer ID Application: NAME (TEAMID)` identity to sign with it instead, once that certificate exists. Blocked on the item above.)
- [ ] Set up notarization (`xcrun notarytool submit` plus stapling) so Gatekeeper doesn't block first launch. (`Scripts/notarize.sh` is written and ready: submits and staples both the app and the DMG. Blocked on the Developer ID certificate above.)
- [x] Build a DMG installer (drag to Applications style), tools like `create-dmg` simplify this. (`Scripts/build-app.sh` assembles the signed `.app` with a real Info.plist and generated icon; `Scripts/make-dmg.sh` packages it into a drag-to-Applications DMG using the built-in `hdiutil`, no extra tools needed. Both tested and working on this machine.)
- [x] Publish the DMG on GitHub Releases or a simple static page, no checkout, no license keys. (Published ad-hoc signed and unnotarized, since notarization is blocked for now (see above). README, the landing page, and the release notes all say so plainly and give both Gatekeeper workarounds, right-click Open and `xattr -cr`. Revisit once notarization is unblocked.)
- [ ] Test the full install flow on a clean Mac/user account: download DMG, drag to Applications, launch, grant permission, it works. (Verified DMG mounting, app bundle launch, onboarding, and the live effect all work on this machine; a truly clean separate Mac/account hasn't been tried.)

Exit criteria: a stranger can download the DMG and get from zero to working app with no terminal commands, no Xcode, and no payment.

---

## Phase 7. Post Launch Iteration (ongoing)

Goal: keep the app alive based on real feedback.

- [ ] Collect early user feedback (support email, socials, GitHub issues) on bugs and requested styles/tweaks.
- [ ] Monitor for macOS beta changes that might break the private lid angle sensor API, private/undocumented APIs can shift between macOS versions.
- [ ] Add small incremental features (new styles, per app exceptions, external keyboard close shortcuts, etc.) based on demand.
- [ ] Version and changelog each update, re-notarize each release.

---

## Rough Total Timeline

| Phase | Duration |
|---|---|
| 0, Feasibility spike | 1-3 days |
| 1, MVP | 1-2 weeks |
| 2, Visual quality | 1-2 weeks |
| 3, App shell | 1 week |
| 4, Robustness | 3-5 days |
| 5, Polish | 2-4 days |
| 6, Packaging and free distribution | 2-4 days |
| Total to v1.0 launch | roughly 5-8 weeks solo, part time friendly |

The biggest unknown is Phase 0, if the lid angle sensor read doesn't work cleanly on your specific hardware/macOS version, everything downstream shifts. Nail that first before committing to the rest of the plan.
