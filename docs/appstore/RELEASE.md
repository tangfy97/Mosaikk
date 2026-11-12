# Mac App Store release

Implemented: native app/framework, bundle ID com.feiyang.collageatelier, version 1.0.0/build 1, Photography category, icons, project type, App Sandbox, user-selected file access, hardened runtime, privacy manifest, AppStore configuration, archive script, and GitHub CI.

Before submitting:

1. Confirm the name and bundle ID in the owner's Apple Developer account; choose the signing team in Xcode or set ATELIER_TEAM_ID.
2. Test minimum/current macOS, Apple silicon/Intel, large realistic projects, keyboard navigation, VoiceOver, contrast, and smaller windows.
3. Resolve old WebKit project migration before replacing an installed version under the same identifier.
4. Create App Store Connect metadata: final description/keywords, price/territories, age rating, support URL, hosted privacy policy, review contact.
5. Capture screenshots from the actual release app with non-personal media. Test permission denial, damaged projects, close/save recovery, and export cancellation.
6. Run `bash scripts/test.sh`, then `ATELIER_TEAM_ID=YOUR_TEAM bash scripts/archive_appstore.sh` with valid Apple Distribution credentials and provisioning.
7. Validate in Xcode Organizer, upload, distribute through TestFlight, address findings, then submit for review.

A local ad hoc build is not a signed store distribution. These scripts do not create account records, pricing, legal agreements, or a store submission.

## Draft copy

Name: Collage Atelier

Subtitle: Good photos. Better together.

Bring photos, screenshots, and visual references together in one quiet workspace. Choose a layout, refine the crop, add a few words, and export a crisp image. Save an editable project with original photos to pick up where you left off.

Four adaptable layouts. Per-photo crop, zoom, rotation, and mirroring. Adjustable spacing, border, corners, and background. Text and highlights. Self-contained documents, native undo, multiwindow editing. PNG/JPEG output and clipboard copy. No accounts, analytics, or cloud uploads.

Final claims must match verified release behavior.
