# Packages And Processing

This document lists the active packages used in the app and what each one does in the app flow.

## Core UI and App
- flutter: App framework, widgets, navigation, rendering.
- cupertino_icons: iOS-style icon set.

## Capture and File Input
- camera: Live camera preview and photo capture for scan flow.
- file_picker: Folder selection for export destination and image picking from device files/gallery sources.
- path_provider: Gets safe app directories and helps resolve fallback storage paths.
- permission_handler: Requests runtime permissions (camera, photos) and can open app settings.

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

## Storage and Permissions Strategy

### Startup Flow
- On app launch, the app requests **Camera** and **Photos & Videos** permissions.
- These are core permissions required for scanning and importing images.
- The app proceeds only when these are granted.

### Permissions Tiers

#### Required Permissions (Block on Startup)
- **Camera**: For capturing scans.
- **Photos & Videos**: For importing from gallery/file picker.
- If denied, user sees a retry/settings option.

#### Optional Permissions (Informational)
- **All Files Access** (MANAGE_EXTERNAL_STORAGE on Android): Allows broader export flexibility.
- If not granted, the app still works—exports go to the app's `my_app/exported` folder.
- User can enable this in Settings later for more export destinations.

### Storage Paths

#### Draft Storage
- Path: `my_app/drafts`
- Purpose: Stores in-progress document scans and edits.
- Writable: Always (no special permission needed).

#### Export Storage
- Path: `my_app/exported`
- Purpose: Stores finalized exported files (PDF or images).
- Writable: Always (no special permission needed).
- **Default behavior**: If user doesn't select an export destination, files go here.

#### Android Storage Details
On Android 11+, the app uses **scoped storage** by default:
- App has dedicated private storage that no app-specific permission is needed to write to.
- If "All Files Access" (MANAGE_EXTERNAL_STORAGE) is enabled by user, the app can save to broader locations like `/storage/emulated/0/my_app`.
- File picker (destination selection) lets users pick folders without needing special permissions.
- Falls back gracefully to app storage if selected destination is not writable.

#### iOS Storage Details
- Photos and gallery import use the standard Photos framework.
- Exports can be saved to Documents or via Files app with scoped access.
- No special storage permission beyond Photos is required.

### User Action to Grant Permissions

1. **On first app launch**: Android shows a dialog asking for Camera and Photos permissions. Tap **Allow All** or individual permissions as prompted.
2. **If Storage Permission is Denied**:
   - The app shows a message noting "All Files Access" is optional.
   - User can tap **Open Settings** to enable it later, or use the app without it.
3. **To Enable "All Files Access" Later**:
   - Go to **Settings > Apps > My App > Permissions > All files access** and toggle it On.
   - (This permission cannot be requested via a normal dialog—it requires manual Settings entry.)

### Export Behavior

- **Without All Files Access**: Exports go to `my_app/exported` automatically.
- **With All Files Access**: User can pick any writable folder; if it fails, fallback to `my_app/exported` with a snackbar message.
- **File Picker**: Once user selects a folder for export, file picker remembers it; no need for all-files permission if the folder is accessible.


