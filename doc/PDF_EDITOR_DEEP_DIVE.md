# PDF Editor Deep Dive

## 1. Purpose

This document describes the current and target architecture for the PDF editor after the hybrid rewrite.

It serves as:
- the implementation map for Flutter and native code
- the phase plan for turning the editor into a production-grade native rendering and mutation system
- the reference for debugging rendering, replay, save, and page synchronization issues
- the source of truth for what is already implemented versus what still needs to be built

## 2. Executive Summary

The editor is being upgraded from a Flutter-driven operation buffer into a fully native rendering and mutation pipeline.

Current foundation:
- Flutter owns the editor UI, gesture capture, and tool state
- MethodChannel `pdf_editor` bridges Flutter to Android and iOS
- Native modules already store operations and page state
- Save currently returns a copied PDF artifact, not yet a true embedded mutation result

Target end state:
- native page rendering surface inside Flutter
- real-time operation replay while drawing
- actual PDF write-back of draw, highlight, text, image, and page edits
- page lifecycle synchronization between Flutter state and native render state

## 3. Current Codebase Snapshot

### 3.1 Flutter editor module

- [lib/features/pdf_editor/screens/pdf_editor_screen.dart](lib/features/pdf_editor/screens/pdf_editor_screen.dart)
- [lib/features/pdf_editor/widgets/editor_toolbar.dart](lib/features/pdf_editor/widgets/editor_toolbar.dart)
- [lib/features/pdf_editor/widgets/tool_config_panel.dart](lib/features/pdf_editor/widgets/tool_config_panel.dart)
- [lib/features/pdf_editor/widgets/canvas_gesture_layer.dart](lib/features/pdf_editor/widgets/canvas_gesture_layer.dart)
- [lib/features/pdf_editor/controllers/editor_controller.dart](lib/features/pdf_editor/controllers/editor_controller.dart)
- [lib/features/pdf_editor/models/tool_type.dart](lib/features/pdf_editor/models/tool_type.dart)
- [lib/features/pdf_editor/models/editor_state.dart](lib/features/pdf_editor/models/editor_state.dart)
- [lib/features/pdf_editor/services/native_pdf_bridge.dart](lib/features/pdf_editor/services/native_pdf_bridge.dart)

### 3.2 Android native module

- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PlatformBridge.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PlatformBridge.kt)
- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfEngine.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfEngine.kt)
- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfRenderer.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfRenderer.kt)
- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfEditor.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/PdfEditor.kt)
- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/DrawingHandler.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/DrawingHandler.kt)
- [android/app/src/main/kotlin/com/pixeldev/Docly/pdf/AnnotationHandler.kt](android/app/src/main/kotlin/com/pixeldev/Docly/pdf/AnnotationHandler.kt)

### 3.3 iOS native module

- [ios/Runner/pdf/PlatformBridge.swift](ios/Runner/pdf/PlatformBridge.swift)
- [ios/Runner/pdf/PdfEngine.swift](ios/Runner/pdf/PdfEngine.swift)
- [ios/Runner/pdf/PdfRenderer.swift](ios/Runner/pdf/PdfRenderer.swift)
- [ios/Runner/pdf/PdfEditor.swift](ios/Runner/pdf/PdfEditor.swift)
- [ios/Runner/pdf/DrawingHandler.swift](ios/Runner/pdf/DrawingHandler.swift)
- [ios/Runner/pdf/AnnotationHandler.swift](ios/Runner/pdf/AnnotationHandler.swift)

### 3.4 Host wiring

- Android host attaches the new bridge in [android/app/src/main/kotlin/com/pixeldev/Docly/MainActivity.kt](android/app/src/main/kotlin/com/pixeldev/Docly/MainActivity.kt)
- iOS host attaches the new bridge in [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift)
- Legacy native drawing engine files were removed

## 4. Architecture Principles

The new editor follows one strict rule:
- Flutter controls interaction and presentation
- Native renders and mutates the PDF

That rule matters because it keeps the editor scalable for:
- signatures
- shapes
- comments
- OCR highlights
- image placement
- future collaboration features

Design goals:
- keep Flutter UI responsive
- keep native rendering deterministic
- avoid visual-only overlays as the final source of truth
- store edits as actual PDF content at save time

## 5. Flutter Layer

## 5.1 Screen responsibilities

`PdfEditorScreen` currently provides:
- save action
- save-as-copy and reset menu actions
- a central native-surface placeholder region
- a transparent gesture capture layer
- page navigation controls
- tool configuration controls
- tool selection toolbar

This screen is already wired to the controller and bridge, but the native render surface is still a placeholder that must be replaced with a real platform view.

## 5.2 State model

`EditorState` carries:
- active tool
- current page
- page count
- stroke width and color
- highlight opacity and color
- text size and color
- saving and busy flags
- view mode flag

The state object is immutable and updated through `copyWith`.

## 5.3 Controller responsibilities

`EditorController` is the Flutter orchestration layer.

It currently:
- initializes the native document
- stores page count
- tracks active tool and style values
- forwards stroke, highlight, text, image, page, and save operations
- batches stroke points before sending them to native
- toggles save state during export

Stroke batching currently uses a small timer loop to reduce per-point channel overhead.

## 5.4 Gesture layer

`CanvasGestureLayer` isolates pointer handling from editor logic.

Active tool behavior:
- draw: pan start/update/end emit stroke points
- highlight: pan gesture builds a rectangle and emits it on end
- text and image: tap emits a placement point

This separation is important because the editor is moving toward native drawing feedback, and gesture capture should remain lightweight.

## 6. Native Bridge Contract

The Flutter bridge uses a single MethodChannel:
- `pdf_editor`

Methods currently supported:
- `loadPdf`
- `drawStroke`
- `addHighlight`
- `addText`
- `addImage`
- `addPage`
- `savePdf`
- `setCurrentPage`
- `getPageCount`

Argument conventions:
- page indexes are 1-based at the Flutter/controller boundary
- coordinates are passed as doubles
- colors are ARGB integers
- stroke point batches are sent as a list of `{x, y}` maps

Both Android and iOS bridges validate inputs and return platform errors when required arguments are missing.

## 7. Native Runtime Model

The native side is already split into four responsibilities.

## 7.1 PdfEngine

`PdfEngine` is the runtime coordinator.

It owns:
- current PDF path
- current page
- renderer
- editor
- drawing handler
- annotation handler

It handles:
- loading the document
- setting the current page
- buffering operations by page
- save dispatch
- disposal

## 7.2 DrawingHandler

`DrawingHandler` stores stroke operations as page-scoped data.

It currently buffers:
- page index
- stroke color
- stroke width
- point list

This is the first step toward replaying the operation stream on demand.

## 7.3 AnnotationHandler

`AnnotationHandler` stores non-stroke operations.

It currently buffers:
- highlight rectangles
- text items
- image placement data

These operations will later be replayed into the rendering surface and written back into PDF output.

## 7.4 PdfRenderer

`PdfRenderer` currently handles PDF loading and page count.

Android version:
- wraps platform `PdfRenderer`
- exposes `pageCount`
- contains a render helper ready for page bitmap extraction

iOS version:
- uses `PDFKit` document loading
- exposes `pageCount`

## 7.5 PdfEditor

`PdfEditor` is currently a save seam.

Current behavior:
- copies source PDF to an output file path
- clears operation buffers after load/save lifecycle transitions

Planned behavior:
- apply buffered operations into the PDF content itself
- return a true edited PDF, not a copied source file

## 8. Production Upgrade Plan

This section describes the next phase the codebase must implement.

## Phase 1: Native Rendering Surface

Goal:
- show a real native-rendered page inside Flutter

Android direction:
- add a render view backed by `TextureView` or `SurfaceView`
- expose it through a Flutter platform view
- draw the base PDF page into a bitmap buffer
- composite overlay output on top

iOS direction:
- add a native view using `UIView` plus CoreGraphics or `CALayer`
- render the PDF page into a CGContext-backed surface
- expose it as a Flutter platform view

Flutter integration:
- replace the placeholder center container with `AndroidView` / `UiKitView` or equivalent platform-view host

Expected outcome:
- the PDF page is visible as native output
- the surface is not a Flutter-drawn image placeholder

## Phase 2: Operation Replay Engine

Goal:
- replay stored operations on top of the base page in real time

Replay order:
1. render base PDF page
2. draw strokes
3. draw highlights
4. draw text
5. draw images

Required behavior:
- replay only the dirty overlay layer
- avoid rebuilding the entire base page bitmap on every pointer event
- keep operations grouped by page

## Phase 3: Real-Time Drawing Loop

Goal:
- make stroke feedback appear instantly while dragging

Flow:
- Flutter gesture
- batched channel payload
- native operation update
- overlay redraw
- frame display

Performance requirements:
- double buffering or equivalent
- avoid full bitmap recreation for every update
- update only the dirty region where possible

## Phase 4: PDF Mutation Pipeline

Goal:
- write buffered operations into actual PDF content

Android direction:
- load the existing PDF document
- iterate pages
- apply vector or annotation operations where possible
- save a new PDF output file

iOS direction:
- mirror the same intent with PDFKit or a PDFium binding

Important rule:
- do not flatten the entire page into a raster unless absolutely required

Operation mapping target:
- draw -> vector stroke or equivalent PDF drawing command
- highlight -> highlight annotation or translucent overlay object
- text -> text object
- image -> embedded bitmap object
- add page -> insert a new page at the correct index

## Phase 5: Page Lifecycle Synchronization

Goal:
- keep Flutter page state and native render state in sync

When page changes:
1. Flutter calls `setCurrentPage`
2. Native updates current index
3. Native renders new base page
4. Native replays operations for that page

Key invariant:
- operations are always grouped by page

## Phase 6: Error Handling and Stability

Required additions:
- try/catch around all native call paths
- structured errors back to Flutter
- strict argument validation
- no silent failures on save or page load

The editor should fail visibly and predictably instead of partially updating state.

## Phase 7: Performance Enhancements

Must include:
- bitmap caching per page
- lazy rendering for pages not in view
- background thread or isolate for heavy work
- image resolution limiting
- path simplification for long strokes

These changes are required to keep the editor responsive on low-end devices.

## 9. Expected Rendering Pipeline

Target frame pipeline:

1. Render or retrieve cached base PDF page bitmap
2. Replay page-specific strokes
3. Replay highlights
4. Replay text annotations
5. Replay images
6. Present composed frame to the native surface

This is the core architectural shift from Flutter overlays to native ownership of the visual output.

## 10. Save Pipeline: Current State vs Target State

## Current state

- Flutter triggers save
- native returns an output file path
- that output is currently a copied PDF artifact

## Target state

- native save path opens the real PDF document
- buffered operations are embedded into the file
- output PDF contains actual persisted edits
- file opens correctly in external PDF apps with all modifications intact

## 11. Page Editing and Mutation Rules

The editor must preserve these invariants:
- all operations belong to a page
- rendering always knows the active page
- save applies only the correct page’s content
- page insertions shift later page mappings consistently

If this is not enforced, stale overlays and incorrect page renders will appear.

## 12. Validation Checklist

The following must be true before this phase is considered complete:
- drawing feels instant while dragging
- highlights appear on the native surface
- text appears immediately and stays attached to the page
- image insertion works and stays positioned correctly
- page switching re-renders the correct content
- save produces a real edited PDF
- output opens correctly in external apps

## 13. What Is Already Done

- Flutter editor module is in place
- native bridge contract exists
- Android and iOS host wiring exist
- native handlers buffer page-scoped operations
- controller batching is implemented
- the old editor stack was removed

## 14. What Still Needs To Be Built

- real native render surface
- replay engine for overlays on each render
- PDF mutation logic that writes actual edits
- full page render lifecycle synchronization
- robust caching and background processing

## 15. Implementation Priority

Recommended order:
1. build the native render surface
2. attach page bitmap rendering and overlay replay
3. wire live redraw from operation updates
4. implement true PDF write-back
5. add page sync and cache strategy
6. harden error handling and performance

## 16. Operational Summary

The project now has the correct long-term boundary:
- Flutter controls interaction
- native code renders and mutates

The current branch is no longer an overlay experiment. It is a real foundation for a production PDF editor, but it still needs the native rendering and mutation phases to become fully complete.
