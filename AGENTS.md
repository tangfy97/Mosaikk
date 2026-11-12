# Mosaikk: handoff for coding agents

Mosaikk is a native macOS photo collage maker (SwiftUI with an AppKit canvas, macOS 14+). Owner: Feiyang Tang (TangSpark). It was rebuilt from scratch on 12 November 2026, replacing the unreleased "Collage Atelier"; the owner chose the name Mosaikk (Norwegian for mosaic). The owner works in Chinese and English; code and docs are in English.

Goal: every collage capability of FotoJet's collage maker (including dragging the borders between photos), with a modern native design matching the other TangSpark apps in `~/Documents` (Spolo, Glimt, Kvikkshot, Maske/MaskCopy). Then GitHub and the Mac App Store.

## Rules

1. The app stays offline: no networking, analytics, accounts or third-party code. If something changes what Mosaikk keeps or shares, update PRIVACY.md in the same change.
2. `project.yml` is the source of truth for the Xcode project. Edit it, then `xcodegen generate`. Never hand-edit `Mosaikk.xcodeproj`.
3. Standard system controls; custom styling only in `Theme.swift`. No explanation paragraphs in the interface (the owner strongly dislikes them): direct manipulation, short labels, help tags.
4. Canvas and export must draw through `Painter`; don't add a second renderer.
5. Every edit goes through `Editor.change` (one undo step) or `beginGesture`/`updateGesture`/`endGesture` (a drag or slider as one step).
6. New user-facing strings need translations in `scripts/translations.py` (zh-Hans, zh-Hant; British spellings in `GB`), then `scripts/localize.sh`.
7. Never commit personal photos; test pictures come from `scripts/sample-photos.swift`.
8. Run `scripts/preflight.sh` before committing; for interface changes, also `scripts/snapshots.sh light` and `dark` and look at the captures. Record open problems in docs/KNOWN_ISSUES.md.
9. The document format (`Collage.formatVersion`) is permanent once released: later versions must still open version 1 files.

## Map

See docs/DEVELOPMENT.md for the architecture, docs/DESIGN.md for the design principles and the FotoJet mapping, docs/APP_STORE.md for releasing.

## Identity

- Bundle ID `com.feiyangtang.Mosaikk`, team X933P26489, document type `com.feiyangtang.mosaikk.collage` (`.mosaikk`).
- Not yet registered in App Store Connect. The old GitHub repository is `tangfy97/CollageAtelier` (private).
