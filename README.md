# Bendd

Bendd is a free, open source macOS menu bar app that makes your desktop visually bend and fold away as you close your laptop lid, like the screen itself is tilting shut.

It runs quietly in the menu bar, costs effectively nothing while the lid is open, and turns on only while the lid is actually closing.

## Requirements

- Apple Silicon MacBook Air or MacBook Pro with a lid angle sensor (MacBook Pro 16-inch 2019, or M2 and later MacBook Air/Pro models)
- macOS 14 or later

## Features

- Live desktop bend driven by the real lid angle sensor, not a canned animation
- Three visual styles: Silk (soft blur), Shade (deep shadow), Frost (blur, shadow, and desaturation)
- Adjustable perspective depth, blur amount, shadow strength, and clear angle
- A drag-to-preview slider in settings to see the effect without physically closing the lid
- Optional chime when the lid opens back up
- Launch at login
- Zero measured idle CPU cost while the lid is open (capture and rendering both fully stop; the sensor itself drops to a coarse polling rate)

## Installing

Prebuilt, notarized releases aren't published yet, that needs a paid Apple Developer Program enrollment which hasn't happened. See `plan.md` for the full status.

To build and run from source:

```sh
cd Bendd
swift build -c release
swift run Bendd
```

To build a local `.app` and a drag-to-Applications DMG (ad-hoc signed, works on your own Mac, will need a right-click-Open past Gatekeeper on anyone else's):

```sh
cd Bendd
./Scripts/build-app.sh
./Scripts/make-dmg.sh
```

## How it works

Bendd reads the lid angle from the same private HID sensor interface used by community projects like [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor), captures the desktop live with ScreenCaptureKit, and renders it as a Metal-textured quad rotated around its bottom edge, with a Gaussian blur and shading pass that scale with how closed the lid is.

See `CLAUDE.md` for a fuller architecture breakdown, and `plan.md` for the phased build history.

## License

MIT, see `LICENSE`.
