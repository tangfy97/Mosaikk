# Collage Atelier

A native Mac app for bringing photos into one frame. Built with SwiftUI, AppKit, ImageIO, and Core Graphics. All processing happens on your Mac.

Requires macOS 14 or later, Xcode 16 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
bash scripts/build_macos_app.sh
open "dist/Collage Atelier.app"
```

To work in Xcode, run `xcodegen generate` and open `CollageAtelier.xcodeproj`. `project.yml` is the source of truth for settings; the generated project is included for convenient opening.

## Use

- Add PNG, JPEG, HEIC, TIFF, WebP, GIF, or BMP images with **⌘I**, the toolbar, or a Finder drop. GIF imports its first frame.
- Choose Grid, Editorial, Columns, or Rows in the Canvas inspector. Set proportions, spacing, border, corners, and background.
- Select a photo to crop, rotate, mirror, replace, or reorder it. Drag inside the photo to adjust its crop; drag filmstrip thumbnails to change order.
- Add text or a highlight from the toolbar. Click an overlay to edit or drag it.
- Save **⌘S** as an `.atelier` project containing original photos and editable settings. Open several projects in separate windows; standard macOS autosave and recent documents apply.
- Export **⇧⌘E** as PNG or JPEG, or copy with **⇧⌘C**. Paste a photo with **⇧⌘V**. Standard undo and redo are supported.
- Toggle the inspector with **⌥⌘I**; return to fit zoom with **⌘0**.

## Code and tests

`Sources/AtelierCore` owns the model, layout, project format, image pipeline, cache, and renderer. `Sources/AtelierApp` owns document integration, editor, inspector, strip, commands, and export UI. There are no third-party runtime dependencies or network entitlements.

```sh
bash scripts/test.sh
```

A project supports up to 200 photos and 512 MB of originals; each photo can be up to 80 MB. Exports are capped at 64 megapixels and 12,000 pixels per side. These are enforced limits, not claims that all maximum-size workflows have been performance-tested. Previews use a 96 MB cost-limited cache; background exports decode one source at a time.

See [design and architecture](docs/plans/2026-11-12-native-redesign.md), [verification](AUDIT.md), and [release preparation](docs/appstore/RELEASE.md).

## Previous editor

The prior webpage editor, AppKit wrapper, and build script are preserved in `legacy/`. The native app does not migrate the old WebKit autosave database or modify it. Keep the old editor available for any existing work until exported. The new build contains no WebKit or browser resources.
