# Packages And Processing

This document lists the active packages used in the app and what each one does in the app flow.

## Core UI and App
- flutter: App framework, widgets, navigation, rendering.
- cupertino_icons: iOS-style icon set.

## Capture and File Input
- camera: Live camera preview and photo capture for scan flow.
- file_picker: Image/file picking support for scan import flows.
- path_provider: Gets safe app directories and helps resolve fallback storage paths.
- permission_handler: Requests runtime permissions (camera, photos) and can open app settings.
- media_scanner: Triggers media indexing after export so files appear in My Files, PDF apps, and Gallery.
- shared_preferences: Available in project dependencies for future preference storage use.

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
- If not granted, the app still works—exports go to the app's `Docly/exported` folder.
- User can enable this in Settings later for more export destinations.

Note: This permission should remain optional. For production and Play Store safety, primary export should rely on app-specific storage, file picker (SAF), and media scanning.

### Storage Paths (Android 11+)

#### Default Storage Location
**Path:** `/storage/emulated/0/Android/data/<package>/files/Docly/`

- Obtained via `getExternalStorageDirectory()` (Android-compliant method)
- **No special permission needed** (safe on Android 11+)
- **Accessible** in Samsung My Files > Android/data (folder hidden but accessible)
- Automatically cleaned up when app is uninstalled
- **Files saved here are persistent** across device reboots

#### Draft Storage (Default)
- Full Path: `/storage/emulated/0/Android/data/<package>/files/Docly/drafts`
- Purpose: Stores in-progress document scans and edits
- Writable: Always (no special permission needed)

#### Export Storage (Default)
- Full Path: `/storage/emulated/0/Android/data/<package>/files/Docly/exported`
- Purpose: Stores temporary/generated files before publishing into Downloads
- Writable: Always (no special permission needed)
- **Default behavior**: Files are generated here first, then copied to public Downloads

#### Public Export Location (Android)
- Target Path: `Downloads/Docly/`
- Export is fixed to Downloads behavior for better user visibility and accessibility
- Android 10+ uses MediaStore write flow via platform channel (`saveFileToDownloads`)
- If MediaStore path fails, app falls back to writable directory strategy

### Why This Works on Android 11+

| Feature | Status | Details |
|---------|--------|---------|
| **Direct public paths** | ❌ Blocked | `/storage/emulated/0/Docly` doesn't work reliably |
| **App-specific external** | ✅ Safe | `getExternalStorageDirectory()` always writable, no permission needed |
| **Optional permissions** | ✅ Flexible | User can enable storage access later if desired |
| **MediaStore Downloads write** | ✅ Preferred | Android 10+ compliant public Downloads export |
| **Scoped storage** | ✅ Compliant | Follows Android's purpose-based storage model |
| **Fallback logic** | ✅ Robust | Automatically uses a writable fallback if Downloads publish fails |

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

- **Default Export Target**: Downloads `Docly` folder (public and user-visible)
- **Export Button**: Generates file(s), then publishes to Downloads
- **Share Button**: Direct share flow using generated PDF bytes
- **Temporary Working Path**: `/storage/emulated/0/Android/data/<package>/files/Docly/exported/`
- **File Accessibility**: Exported files are scanned/indexed for visibility in file managers and viewers

### Premium Export Experience (Implemented)

The app now uses a simplified export UX focused on reliability and visibility.

1. **File Visibility UX**
- After successful export, media scanner is triggered on exported output paths.
- PDF export scans the saved PDF file path.
- Image export scans each exported image file path.
- Outcome: Files appear in My Files, PDF apps, and Gallery faster on Android 13+.

2. **Export Actions UX**
- Primary actions are:
   - Share (left button)
   - Export (right button)
- Save As menu and destination picker were removed to avoid conflict/fallback confusion.

3. **Fixed Destination Strategy**
- Destination is fixed to Downloads-first publishing.
- App-private storage is used as staging/temporary output only.
- This avoids inaccessible custom-folder failures on Android 14+.

4. **Downloads Strategy Hardening (MediaStore-first)**
- Android 10+ uses MediaStore APIs through native method channel to save into Downloads.
- Legacy/direct path fallback is only used when needed.
- This aligns with scoped storage and improves user file discovery.

5. **Share Path**
- Share is a primary button action.
- Share generates PDF output and opens platform share UI.
- If image mode is selected, sharing still uses PDF for compatibility across receiving apps.

### Viewing Exported Files on Device

1. **On Samsung**: Open **My Files** > **Android** > **data** > **com.pixeldev.Docly** > **files** > **Docly**
2. **On Stock Android**: Use a file manager app, navigate to `/Android/data/<package>/files/Docly`
3. **By Default**: Files appear in **Downloads** > **Docly** after export
4. **Via USB Cable**: Connect phone to PC, navigate to `Internal Storage/Android/data/<package>/files/Docly/`


