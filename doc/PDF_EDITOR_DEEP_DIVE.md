# PDF Editor Deep Dive

## 1. Purpose

This document explains the full internal architecture, data flow, performance model, and save pipeline of the PDF editor implemented in `lib/features/files/screens/pdf_editor_screen.dart`.

It is written for:
- Future maintainers
- Performance tuning work
- Bug fixing for overlay, gestures, and persistence
- Feature extension (new tools, signatures, shape tools, comments)

## 2. High-Level Architecture

The editor uses a hybrid approach:
- PDF viewing and base rendering: `syncfusion_flutter_pdfviewer`
- Interactive overlays (draw, highlight, text, image): custom Flutter overlay layer
- PDF page insertion and final flatten save: `syncfusion_flutter_pdf`

This hybrid design gives:
- Stable and optimized PDF rendering from native-backed viewer engine
- Flexible editing UI in Dart
- Ability to burn overlays into real PDF bytes on save

## 3. Core Runtime Components

### 3.1 Screen and Controller
- `PdfEditorScreen` is a stateful route dedicated to editing
- `PdfViewerController` handles page jumps, zoom, and source document snapshot (`saveDocument`)

### 3.2 Tool System
Tool enum:
- none
- highlighter
- draw
- text
- image
- addPage

Tool state drives:
- Which gesture handlers are active
- Which settings panel is visible
- Whether base PDF gestures are absorbed in edit mode

### 3.3 Overlay Data Model
Overlay data is page-scoped:
- `_overlaysByPage: Map<int, _PageOverlayData>`

Each page contains:
- `strokes`: freehand paths for draw/highlight
- `texts`: movable/resizable text boxes
- `images`: movable/resizable image boxes

All coordinates are canvas-space and normalized when persisted to sidecar.

## 4. One-Page-at-a-Time Editing Model

Editor behavior is intentionally constrained:
- `pageLayoutMode: PdfPageLayoutMode.single`
- Next/Previous buttons are primary navigation
- Swipe page changes are blocked unless the jump was programmatic

Mechanism:
- `_allowProgrammaticPageJump` flag
- On `onPageChanged`, if a change was user swipe and not flagged, page is immediately reverted to old page
- On button press, flag is set before `jumpToPage`

This prevents accidental page movement while editing and keeps gestures deterministic.

## 5. Performance Strategy

### 5.1 Repaint Isolation
Main optimization:
- Overlay frame updates no longer trigger full scaffold rebuild
- `ValueNotifier<int> _overlayTick` drives overlay-only redraw
- Overlay stack wrapped in `RepaintBoundary`

Result:
- Draw/highlight movement updates repaint only overlay region
- Viewer and app bar do not rebuild per pointer event

### 5.2 Stroke Point Thinning
- `_appendStrokePoint` inserts points only when distance exceeds threshold (`~1.4` px)
- Reduces path complexity and paint workload
- Improves smoothness on lower-end devices

### 5.3 Dirty-State Handling
- `_markOverlayDirty` marks unsaved state once and then uses light overlay tick updates
- App bar dirty indicator avoids expensive state churn while preserving UX feedback

### 5.4 Image Input Optimization
Imported images are resized before overlay insertion:
- Uses `ui.instantiateImageCodec(... targetWidth: 1280)`
- Converts to PNG bytes
- Reduces decode/paint pressure and memory spikes

## 6. Tool Behavior Details

### 6.1 Draw and Highlight
Both use the same custom stroke pipeline:
- Start/update/end gesture lifecycle
- Active preview stroke while dragging
- Stroke persisted at gesture end

Differences:
- Draw uses draw settings (color, width, opacity, eraser)
- Highlight uses highlight settings (color, fixed thicker width, opacity)

### 6.2 Text Tool
Current flow:
- Tap canvas inserts a new text item
- Text item can be selected, moved, resized
- Double tap opens text edit sheet

Selection UX:
- Selected text item shows border and control handles
- Close handle removes item
- Resize handle updates width/height

### 6.3 Image Tool
Flow:
- Pick from gallery
- Image is optimized and inserted centered on canvas
- Selection enables move, remove, resize

Important interaction guard:
- Canvas tap no longer clears image selection while image tool is active
- Prevents immediate deselect race and broken close/resize behavior

### 6.4 Add Page Tool
Add-page menu allows insertion position:
- After any existing page
- At end

Backend:
- Loads PDF bytes with `syncfusion_flutter_pdf`
- Inserts blank page at computed index
- Saves bytes back to original path
- Rewrites overlay map page indexes for pages shifted by insertion
- Reopens editor route to refresh viewer state from modified file

## 7. Save Pipeline (Critical)

### 7.1 Why previous saves felt broken
Earlier, overlays were primarily sidecar-persisted (`.docly_overlay.json`) and not always flattened into PDF content.

### 7.2 Current save flow
When save is triggered:
1. `PdfViewerController.saveDocument()` retrieves current viewer PDF bytes
2. `_renderOverlayIntoPdf` opens bytes with `syncfusion_flutter_pdf`
3. For each page overlay:
   - Draws all stroke segments onto page graphics
   - Draws text backgrounds and text
   - Draws image bitmaps
4. Saves merged PDF bytes
5. Writes merged bytes to target path (original or copy)
6. Scans saved file in media store
7. Clears sidecar for that target path to prevent duplicate visual stacking
8. Clears in-memory overlays and resets dirty state

Outcome:
- Draw/highlight/text/image edits are now embedded in actual PDF output

## 8. Overlay Sidecar Strategy

Sidecar file path:
- `<pdfPath>.docly_overlay.json`

Used for:
- Session resilience before flatten-save
- Draft overlay restore if needed

After flatten-save to final target:
- Sidecar is deleted for that target
- Avoids reapplying already-burned overlays

## 9. UI/UX Improvements Implemented

- Save-to-original moved to top app bar (single-tap)
- Overflow menu simplified (Reset + Save as Copy + Cancel)
- Page title styling made compact for better visibility
- Tool and page navigation bars use brighter gradients (less dull visual tone)
- Unsaved marker dot displayed in app bar

## 10. Known Constraints and Future Enhancements

### 10.1 Current constraints
- Text editor still uses bottom-sheet for full content editing (double tap)
- Inserted pages are blank (no template cloning)
- Overlay flattening uses simple text rendering and line segments

### 10.2 Recommended future work
- Inline editable text box (no sheet) with keyboard focus controls
- Undo/redo stack per page and per object operation
- Spline smoothing for strokes
- Tiled overlay rendering for very dense documents
- Background isolate for heavy image preprocessing
- Add-page options (blank, duplicate current page, import image as page)

## 11. Failure Modes and Diagnostics

If red framework errors appear:
- Validate that only one annotation interaction path is active
- Confirm `enableTextSelection` remains disabled in editor mode
- Check that on-page overlays are not mixing external annotation engine state

If saving still appears missing:
- Verify `_renderOverlayIntoPdf` is executed before file write
- Confirm no stale sidecar overlays are being displayed after save
- Test save as copy and inspect copy externally

If drawing lags:
- Check if `_overlayTick` updates are used instead of broad `setState` during pan updates
- Verify imported image sizes are optimized
- Reduce max target image width further for low-end devices

## 12. Extension Guide

To add a new tool:
1. Add enum value in `_EditorCanvasTool`
2. Add tool chip in toolbar
3. Add settings panel section in `_buildToolConfigPanel`
4. Add rendering logic in overlay stack or painter
5. Include serialization in sidecar and flatten-save pass

## 13. Files Involved

Primary:
- `lib/features/files/screens/pdf_editor_screen.dart`
- `lib/features/files/models/pdf_edit_models.dart`
- `lib/features/files/widgets/editor_tool_panel.dart`

Persistence and I/O:
- `lib/features/documents/data/document_storage_service.dart`

## 14. Operational Summary

Editor now follows a staged, performance-focused execution model:
- Small interactive tasks in overlay layer
- Minimal repaint scope for high-frequency input
- Controlled page navigation
- Explicit flatten merge to final PDF bytes on save

This is the correct base for scaling to a production-grade mobile PDF editor.
