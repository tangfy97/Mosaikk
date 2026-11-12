# Native redesign verification · 2026-11-12

The original audit is preserved at legacy/AUDIT.md. This file describes the native rewrite.

## Evidence

Source review covered the original WebKit bridge, editor, persistence, and export paths. The original app was opened and inspected. Local design references came from Maske, Spolo, Kvikkshot, and Glimt, including a rendered Spolo App Store screenshot. No personal media is included in committed test fixtures or screenshots.

The rebuilt app was opened through native computer-use tools. Inspection covered the welcome screen, populated canvas, photo inspector, canvas settings, overlay inspector, export sheet, save dialogs, and inspector collapse at the default 1180 × 800 pt window. Screenshots were inspected in the task session. A smaller-window resize attempt did not establish a changed window size; compact-window QA remains unverified. Both light and dark appearances were inspected in the optimized Release app. The app-specific appearance preference was restored to System afterward.

## Fixed

- Replaced the WebKit shell and single-file JavaScript editor with a native SwiftUI app, an independent core framework, and a normal Xcode project. The old implementation remains recoverable under legacy/.
- Replaced competing card/toolbars with a native toolbar, central canvas, photo strip, and collapsible inspector. Canvas settings, photo controls, and overlays occupy separate tabs.
- Added named, self-contained .atelier documents containing originals and editing data. Native saving and reopening were exercised: both photos, editorial layout, a caption, and two highlights restored correctly. Autosave also persisted the caption during the session.
- Exercised import from the native file picker with isolated procedural images, layout switching, undo/redo, photo rotation, reorder/undo, text edits, highlight insertion/dragging, and inspector collapse.
- Exported a 2400 × 1800 PNG through the actual UI and opened the output for visual verification. Caption and photo placement were present. Renderer tests also verify JPEG dimensions, alpha handling, and image orientation.
- Added explicit replacement, error reporting, bounded imports/preview caching, sequential export rendering, atomic writing, cancellation, and corrupt-project validation.
- Corrected canvas photo accessibility grouping found during native inspection; the Release accessibility tree now exposes all six canvas photos by name. Keyboard-only and full VoiceOver testing are not claimed.
- Changed export to Shift-Command-E to avoid the native text editor's Command-E action; the shortcut opened the export sheet while a dimension field had focus in the Release app.

## Automated checks

Swift Testing exercises schema rejection, invalid and duplicate values, missing assets, archive round trips including crop/rotation/mirroring/overlays, orphan omission, incomplete-grid coverage, layout non-overlap through 200 photos and extreme aspect ratios, crop geometry for four rotations, invalid images, EXIF orientation, PNG/JPEG dimensions and transparency, cancellation, unsafe export dimensions, pixel orientation, and an actual 200-photo render. All sources use Swift 6. Build and test logs are under ignored build/.

The Debug build succeeded and was ad hoc signed with App Sandbox plus user-selected file access. The optimized universal Release build succeeded; 16 tests in three suites passed, including an actual 200-photo render. Plists and shell script syntax passed validation. The Release app was revisited for the six-photo editorial layout, light/dark appearance, accessibility grouping, and the export shortcut. GitHub CI runs package tests and a Release build; remote CI must be checked after the first push.

## Release gaps

Not yet established: real-device memory/launch profiling, maximum-source-size workloads, Intel and macOS 14 runtime QA, compact-window resizing, full keyboard/VoiceOver/contrast checks, Photos-library picker, browser remote-URL import, old WebKit database migration, signed App Store archive validation, TestFlight, public privacy/support URLs, final store screenshots, and App Review submission. The new app accepts local-file drops and clipboard images; it has no network entitlement.

App Store preparation is in docs/appstore/RELEASE.md. A successful local build does not mean the app has been submitted or approved.
