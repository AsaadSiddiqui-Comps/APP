# Packages And Processing

This document lists the active packages used in the app and what each one does in the app flow.

## Core UI and App
- flutter: App framework, widgets, navigation, rendering.
- cupertino_icons: iOS-style icon set.

## Capture and File Input
- camera: Live camera preview and photo capture for scan flow.
- file_picker: Folder selection for export destination and image picking from device files/gallery sources.
- path_provider: Gets safe app directories and helps resolve fallback storage paths.
- permission_handler: Requests runtime permissions (camera, media/storage) and opens app settings when permissions are denied.

## Document Creation and Processing
- image: Image decoding, resize, and JPEG re-encoding before PDF generation to improve stability and output size.
- pdf: Builds PDF documents from scanned pages.
- printing: Print/share support for generated PDFs.
- pdfium_flutter: PDF rendering backend dependency prepared for advanced PDF viewing/rendering workflows.

## ML and Vision
- google_ml_kit: ML utilities and base model integration support.
- google_mlkit_document_scanner: Document scanning capabilities using ML Kit.
- google_mlkit_commons: Shared ML Kit utilities used by scanner-related APIs.
- opencv_dart: OpenCV-based image processing utilities.

## Storage Processing Logic
- Draft files are stored in: my_app/drafts
- Exported files are stored in: my_app/exported
- Preferred Android root path: /storage/emulated/0/my_app (if writable with granted permissions)
- Fallback root path: app documents directory (private app sandbox)

## Runtime Permission Processing
- On app startup, required permissions are requested before entering the home screen.
- If any permission is denied, the app shows a permission gate with Retry and Open Settings actions.
- If a permission is permanently denied, user must grant it from system settings.
