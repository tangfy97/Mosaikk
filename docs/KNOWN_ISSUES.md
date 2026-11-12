# Known issues

Open problems and things not yet verified, so they don't live only in a conversation.

## Not yet verified

- **Hands-on testing by a person.** The interface has been checked with the scripted snapshot session (real mouse events for border dragging and swapping) in light, dark and Chinese, but not yet clicked through by hand: pinch zoom, Photos-picker import, drag from Photos and Finder, inline text editing, the context menus and keyboard nudging need a manual pass.
- **macOS 14 and 15.** Built and run on macOS 27 with Xcode 27; the deployment target is macOS 14, and CI builds on Xcode 16 (macos-15), but the app hasn't been run on 14 or 15.
- **Large collages.** 25-cell layouts and 500 pictures are allowed; memory and drawing speed with many 50-megapixel originals haven't been measured. Previews are capped at 600 MB.
- **VoiceOver.** Sidebar and inspector controls are standard and labelled; the canvas itself is one image to VoiceOver, so cells and items can't be selected without a pointer.

## Open

- **Text is edited unrotated.** Typing into a rotated text item shows the editor level, then the text turns back when editing ends.
- **One selection at a time.** No multi-select for moving or deleting several items at once.
- **No curved text, no free-form crop rectangle** (crop is zoom and position within the frame), and no arbitrary-angle rotation of a photo inside its cell (quarter turns only).
- **Grid layouts are guillotine cuts.** Pinwheel arrangements that can't be made by splitting rectangles aren't possible as a grid; a floating frame can stand in.
- **Untitled export name.** Export suggests “Collage” when the document has no name yet.
- **App Store screenshots** in `docs/appstore/screenshots/en` are from the snapshot session with generated pictures; they show “Untitled — Edited” in the title bar.
