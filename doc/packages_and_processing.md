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
- media_scanner: Triggers media indexing after export so files appear in My Files, PDF apps, and Gallery.
- shared_preferences: Persists selected export folder and related export options across app restarts.

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

Note: This permission should remain optional. For production and Play Store safety, primary export should rely on app-specific storage, file picker (SAF), and media scanning.

### Storage Paths (Android 11+)

#### Default Storage Location
**Path:** `/storage/emulated/0/Android/data/<package>/files/my_app/`

- Obtained via `getExternalStorageDirectory()` (Android-compliant method)
- **No special permission needed** (safe on Android 11+)
- **Accessible** in Samsung My Files > Android/data (folder hidden but accessible)
- Automatically cleaned up when app is uninstalled
- **Files saved here are persistent** across device reboots

#### Draft Storage (Default)
- Full Path: `/storage/emulated/0/Android/data/<package>/files/my_app/drafts`
- Purpose: Stores in-progress document scans and edits
- Writable: Always (no special permission needed)

#### Export Storage (Default)
- Full Path: `/storage/emulated/0/Android/data/<package>/files/my_app/exported`
- Purpose: Stores finalized exported files (PDF or images)
- Writable: Always (no special permission needed)
- **Default behavior**: If user doesn't select an export destination, files go here

#### Custom Export Location (Optional)
- User can tap **"Change"** button to pick any folder
- File picker lets users select any writable folder without needing MANAGE_EXTERNAL_STORAGE
- If selected folder becomes inaccessible, fallback to default export folder automatically

#### Optional Public Export (Android Only)
- Path: `/storage/emulated/0/Download/my_app/`
- Direct path usage is risky on Android 11+ unless SAF or MediaStore is used
- Prefer file picker destination selection (SAF) or MediaStore-based save flows for Downloads

### Why This Works on Android 11+

| Feature | Status | Details |
|---------|--------|---------|
| **Direct public paths** | ❌ Blocked | `/storage/emulated/0/my_app` doesn't work reliably |
| **App-specific external** | ✅ Safe | `getExternalStorageDirectory()` always writable, no permission needed |
| **Optional permissions** | ✅ Flexible | User can enable storage access later if desired |
| **File picker support** | ✅ Works | Folder selection without needing broad permissions |
| **Scoped storage** | ✅ Compliant | Follows Android's purpose-based storage model |
| **Fallback logic** | ✅ Robust | Automatically uses safe storage if selected folder fails |

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

- **Default (No Selection)**: Exports go to `/storage/emulated/0/Android/data/<package>/files/my_app/exported/`
- **Custom Folder Selected**: Tries selected folder; if fails, fallback to default with message
- **Downloads Mode Selected**: Uses SAF-selected Downloads folder first, then tries `/storage/emulated/0/Download/my_app/` if writable, then falls back to app export folder
- **File Accessibility**: Exported files are scanned with media scanner so they appear in file managers and viewer apps
- **Selection Persistence**: Destination mode and selected paths are restored on next app launch using SharedPreferences

### Premium Export Experience (Implemented)

The app now includes a full Save As flow and reliable destination handling.

1. **File Visibility UX**
- After successful export, media scanner is triggered on exported output paths.
- PDF export scans the saved PDF file path.
- Image export scans each exported image file path.
- Outcome: Files appear in My Files, PDF apps, and Gallery faster on Android 13+.

2. **Export Options UX (Save As Bottom Sheet)**
- Save As sheet includes all 4 actions:
   - Default (App Storage)
   - Choose Folder
   - Save to Downloads
   - Share
- Both destination change actions route through this same sheet for consistent UX.

3. **Persistent Folder Selection**
- Destination mode is persisted (app storage, custom folder, downloads).
- Custom folder path and Downloads SAF path are saved with SharedPreferences.
- On next export, the app restores mode and attempts saved paths first.
- If path is no longer writable, export falls back safely to app storage.

4. **Downloads Strategy Hardening (SAF-first)**
- Downloads mode uses this order:
   - SAF folder picked by user (preferred)
   - Direct `/storage/emulated/0/Download/my_app` only if writable
   - App export folder fallback
- This reduces failures on scoped storage devices while keeping practical fallback behavior.

5. **Share Path**
- Save As includes Share action.
- Share generates PDF output and opens platform share UI.
- If image mode is selected, sharing still uses PDF for compatibility across receiving apps.

### Viewing Exported Files on Device

1. **On Samsung**: Open **My Files** > **Android** > **data** > **com.example.my_app** > **files** > **my_app**
2. **On Stock Android**: Use a file manager app, navigate to `/Android/data/<package>/files/my_app`
3. **If Downloads Mode Is Used**: Files can appear in **Downloads** > **my_app** when Downloads destination is writable/selected
4. **Via USB Cable**: Connect phone to PC, navigate to `Internal Storage/Android/data/<package>/files/my_app/`


