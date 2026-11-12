# Design

Mosaikk should feel like the other TangSpark apps (Spolo, Glimt, Kvikkshot, MaskCopy): a well-made Mac tool from a small studio, quiet and obvious. It has every capability of a full web collage maker such as FotoJet, without its look: no ads, no upsell panels, no tiny icon rows and no modal wizards. When a change is in doubt, these decide.

## Behaviour

1. **Direct manipulation first.** Borders are dragged, photos are panned by dragging inside their cell and swapped by dragging onto another cell, items have handles, text is typed on the canvas. The inspector is for precision, not the only way in.
2. **Never lose work.** Every change is one undo step, including a whole drag or slider move. Adding photos never replaces a filled cell; changing the layout keeps the photos, in order, and the rest stay in the library. Collages are documents with autosave and versions, and they carry their original photos.
3. **What you see is what you export.** The canvas and the exporter draw with the same painter, so filters, text, shadows and patterns match exactly.
4. **Native before custom.** Toolbar, sidebar, inspector (grouped forms), menus, sheets, colour wells, the Photos picker and the share menu come from the system. Custom drawing is limited to the canvas, the layout and sticker previews, and swatches.
5. **Quiet.** No onboarding or explanation paragraphs. Empty cells show a plus; the first window is a ready layout, not a welcome screen. Labels are short and specific; details go into help tags.
6. **Offline.** No network, accounts or analytics. Stickers and patterns are drawn in code; there is no stock content to license.

## Look

- **Neutral surroundings.** The canvas sits on neutral grey (light or dark) so it doesn't change how the photos look; selection uses the accent colour.
- **The house toolbar.** Undo and Redo beside the title, then flat labelled buttons (Add, Text, the canvas size, Share, Export) and the inspector toggle, with no capsules on macOS 26 — the same as Spolo.
- **Three columns with one job each.** The sidebar answers *what to add* (layouts, photos, text styles, stickers, backgrounds), the canvas *where it goes*, the inspector *how the selected thing looks*. With nothing selected the inspector shows the collage: size, cells and background.
- **Accent colour.** Coral (#E0604A), from the icon. Everything else is system colour.
- **Icon.** A collage board of three photos on a dusk-blue tile, in the same palette and tile as Spolo and Glimt. `scripts/icon.swift` renders it.

## Mapping FotoJet's collage maker

| FotoJet | Mosaikk |
|---|---|
| Classic / Photo Grid templates by count | Layouts tab, filtered by count (defaults to the number of photos added) |
| Creative templates with shaped frames | Shapes layouts, frame shape per cell, templates with a floating frame |
| Freestyle collage | Freeform layout; photos added are scattered as bordered prints |
| Drag borders to resize | Border dragging with aligned borders moving together, snapping to other borders, minimum size |
| Spacing, roundness | Spacing, margin, corners, and a cell shadow |
| Photo: crop slider, rotate, flip, effects, opacity, exposure, brightness, contrast, saturation, hue | Zoom and pan, quarter turns, flips, 16 filters with strength, 12 adjustments; opacity on free photos |
| Text: fonts, size, B/I/U, alignment, opacity, outline, glow | All of these, plus letter spacing, line height, capitals, shadow and a highlight box |
| Clipart | Stickers: shapes, badges, decorations, emoji (drawn in code) |
| Background colour, gradient, pattern | Plus a blurred photo and transparency |
| Layer order, duplicate, delete, lock | Same, plus snapping guides and ⌥-drag to duplicate |
| Custom size, presets | Proportions, social and print presets, custom pixels with locked proportions |
| Save project, JPG/PNG download | `.mosaikk` documents with originals; PNG, JPEG, HEIC at any size; copy and share |
| Online photo library, cloud storage, premium content | Not included: Mosaikk is offline, and adds from Finder, the Photos picker, drag and drop and paste |
