# Native Mac redesign · 2026-11-12

## Direction

A local photo collage editor: collect photos, screenshots, and references; arrange and crop; save an editable document; export an image. macOS 14 and later. No backend or account is needed for this task.

Local reference sources: Maske's Theme.swift; Spolo's editor and toolbar; Kvikkshot's content and filmstrip; Glimt's AppKit toolbar. Spolo's App Store screenshot was inspected. The common language is native controls, content-first layouts, paper/ink neutrals, and restrained emphasis. References are not runtime dependencies.

## Visual system

Native window title bar, traffic lights, menus, dialogs, and inspector. The central canvas is above a horizontal photo strip. One collapsible inspector groups canvas, photo, and overlay controls. Semantic system backgrounds and text support light and dark appearance. Fjord blue identifies actions and selection. Actual collage colors remain independent of system appearance.

System sans serif controls; system serif in the welcome and export introductions. Type roles: 30 pt welcome, 24 pt export introduction, 12–13 pt controls, 11 pt section/supporting text, 10 pt photo metadata. Spacing roles: 4, 8, 12, 16, 20, 28, 40 pt. Cards are limited to layout selection. Selection uses outlines and accessibility traits. Native controls own keyboard focus and disabled states. No decorative motion. Settings allow System, Light, and Dark appearance, stored in app-local preferences with the UserDefaults privacy reason declared.

## Architecture and extension points

AtelierCore is a Swift 6 module, built as a framework by Xcode and a library by Swift Package Manager. It owns versioned Codable models, validation, layout geometry, archives, decoding, caching, and export. The app owns platform integration and user intent. No third-party runtime dependencies.

AtelierDocument integrates ReferenceFileDocument and DocumentGroup for named documents, multiwindow editing, native save/close handling, autosave, and recents. Mutations run on the main actor; a lock protects immutable copy-on-write snapshots for file writing. Undo retains model snapshots rather than duplicate image bytes. EditorSession holds transient selection, dialogs, status, and activity; those are not project data.

New layout algorithms return PhotoFrame geometry from the core. Preview and export share ImagePlacement for crop/rotation/mirror calculations. New encoders extend the renderer without coupling to the editor. A future second platform can reuse the core after separating the small macOS file-access boundary; no cross-platform UI claim is made now.

## Storage, media, and limits

The .atelier package contains project.json and Assets/<UUID>. Source names are labels, never filesystem paths. Originals travel with the document. Validation rejects unknown schemas, duplicate IDs, invalid numbers, missing assets, and oversized content. Deleting a photo omits it from the saved package while retaining its original in memory for undo. Undo-retained originals can increase memory until the document closes.

User-chosen or dropped files are read under scoped access, then copied into the document. ImageIO verifies decodability and applies EXIF orientation. Imports append; replacement is explicit and undoable. Previews are downsampled outside the main actor with a 96 MB cost-limited cache. Export processes sources sequentially, renders sRGB, creates fresh PNG/JPEG metadata, and writes atomically. JPEG flattens transparency on white. Export scaling preserves design-space spacing, margins, and annotations.

Explicit limits: 200 photos; 80 MB each; 512 MB active originals; 50 captions and 50 highlights; 12,000 px per side; 64 MP output. These are guardrails, not performance measurements. Profile realistic maximum workloads before raising them.

## Verification and migration

Core tests cover document round trips and damage, invalid model values, geometry and non-overlap through 200 photos/extreme proportions, EXIF orientation, output dimensions/transparency, cancellation, and pixel orientation. Procedural non-personal fixtures live under ignored build/verification. Native QA follows import → crop/order/overlay → undo → save/reopen → export, with small-window and appearance checks. VoiceOver and minimum-OS release checks remain explicit release requirements until performed.

The original editor is preserved under legacy/. Its WebKit database is untouched. Automated migration is not implemented; retain the legacy app to export old work before replacing an installed distribution.

## Distribution

Xcode project, icon sizes, document registration, App Sandbox, user-selected access, hardened runtime, privacy manifest, AppStore configuration, archive script, and CI are provided. Final signing, store record, support/privacy URLs, pricing, screenshots, and submission require the owner's release account and decisions.

Platform sources: [document-based SwiftUI apps](https://developer.apple.com/documentation/swiftui/building-a-document-based-app-with-swiftui/) and [App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox).
