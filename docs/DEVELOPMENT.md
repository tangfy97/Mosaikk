# How Mosaikk works

```
Sources/MosaikkCore/      the engine: no AppKit or SwiftUI, tested on its own with `swift test`
  Collage.swift           the document model: canvas, grid, cells, photos, looks, assets, normalising
  Layout.swift            the grid as a tree of weighted splits; geometry, borders and dragging them
  Templates.swift         the built-in layouts, generated from a small layout language
  Editing.swift           editing operations (add, auto fill, shuffle, split, swap, arrange) and canvas presets
  Items.swift             the free layer: photos, text and stickers, and backgrounds
  Shapes.swift            frame shapes and the sticker catalogue, as paths
  Filters.swift           filters and adjustments with Core Image
  TextLayout.swift        text with Core Text
  Painter.swift           draws a collage into any CGContext; used by the canvas and export
  Rendering.swift         bitmap rendering and image files
  Images.swift            reading pictures with ImageIO
  DocumentFile.swift      the .mosaikk package
Sources/MosaikkApp/       the Mac app (SwiftUI, with an AppKit canvas)
  MosaikkApp.swift        DocumentGroup and menus
  MosaikkDocument.swift   ReferenceFileDocument; saving runs off a locked snapshot
  Editor.swift            per-window state: the collage, selection, undo, importing
  CanvasView.swift        the canvas: drawing, hit testing, dragging, handles, typing, dropping
  Sidebar.swift           layouts, photos, text styles, stickers, backgrounds
  Inspector.swift         settings for the selection, or for the collage
  PreviewImages.swift     decoded and filtered pictures, prepared in the background
  ExportSheet.swift, Presets.swift, Theme.swift
  Snapshots.swift         the scripted design-snapshot session (Debug builds only)
```

## The model

A `Collage` is a value. Every edit makes a new value, and undo keeps the previous one, so undo is exact and simple. Positions are fractions of the canvas, and lengths (spacing, borders, text size) are fractions of its shorter side, so changing the canvas size or exporting at any resolution keeps the look.

The grid is a tree. A split has two or more children with weights, laid out in a row or a column; leaves are cells. Three equal columns are one split, so dragging a border between two columns only changes those two. `LayoutGeometry` turns the tree into rectangles and the borders between them; `LayoutNode.moving` moves one border while keeping every cell above a minimum size. Borders that line up across rows are found by `aligned(with:reach:)` and dragged together.

Cells and the photos in them are separate: a cell can be empty, a picture can be used in several places with different crops and looks, and the library (`assets`) holds every picture added, used or not.

## Drawing

`Painter` draws the background, the cells (clipped to their shape, with the photo placed by its crop), then the free layer, into a context whose user space is the canvas with y pointing down. It asks for pictures through a closure with an `ImageRequest` (picture, look, size): the canvas answers from `PreviewImages`, which decodes and filters in the background and shows the nearest copy it has meanwhile; export decodes each picture at the size it is drawn. Both use the same `LookRenderer`.

## The document

A `.mosaikk` file is a package: `collage.json`, the original pictures in `Pictures/`, and `QuickLook/Thumbnail.png` for Finder. Saving reuses picture files already in the package. Opening checks everything: values are clamped, references to missing pictures removed, and a file from a newer version is refused with a clear message. The format version is `Collage.formatVersion`; any change to the JSON needs a decoder that still reads version 1.

## Checks

- `scripts/test.sh`: engine tests for geometry, border dragging, templates (no overlaps, inside the margins), editing, rendering pixels (orientation, flips, crop panning, transparency), filters, and the document round trip.
- `scripts/snapshots.sh [light|dark] [language]`: a Debug-only scripted session (`MOSAIKK_SNAPSHOT`) that adds generated pictures, drags a border and swaps photos with real mouse events, applies a filter, adds text and stickers, changes the background, undoes, saves through NSDocument and reads the file back, and captures the window after each step. It prints PASS or FAIL for each check.
- `scripts/preflight.sh`: everything above that can run unattended, plus both release builds and their shipping settings.
