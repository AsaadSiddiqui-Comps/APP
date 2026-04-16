# Flutter App Dependency Audit

This file summarizes the current Flutter app state and explains why each dependency in `pubspec.yaml` exists.

## App check (current implementation)

- App entry is `lib/main.dart`, which launches `PermissionGateScreen`.
- Core flow: permission gate → home screen → camera/gallery import → editor → export.
- Document export supports PDF and image export with Downloads-first saving behavior.
- Local draft/export storage is handled by `DocumentStorageService`.

## Dependencies and reasons

### Runtime dependencies (`dependencies`)

| Dependency | Why it is in the app | Current usage status |
|---|---|---|
| `flutter` | Core Flutter SDK for UI, app lifecycle, routing, and rendering. | Used throughout `lib/` |
| `cupertino_icons` | iOS-style icon font package. | Declared, no direct icon usage found in `lib/` currently |
| `camera` | Camera preview, capture, and image file model (`XFile`) for scan flow. | Used in camera, home, editor, and export flows |
| `file_picker` | Gallery/file selection for importing images into scan/editor flow. | Used in `home_screen.dart` and `camera_capture_screen.dart` |
| `path_provider` | Resolves app-safe writable directories for drafts/exports. | Used in `document_storage_service.dart` |
| `permission_handler` | Requests and checks runtime permissions (camera/photos/storage settings). | Used in permission service and permission gate screen |
| `media_scanner` | Triggers Android media indexing after export so files appear in file managers/apps. | Used in `document_storage_service.dart` |
| `shared_preferences` | Key-value local persistence package. | Declared; no direct usage in `lib/` currently |
| `pdf` | Builds PDF documents from captured/imported images. | Used in `document_export_service.dart` |
| `printing` | Print/share actions for generated PDFs. | Used in export screen |
| `google_ml_kit` | Base ML Kit integration package. | Declared; no direct usage in `lib/` currently |
| `google_mlkit_document_scanner` | ML Kit document scanner integration. | Declared; no direct usage in `lib/` currently |
| `google_mlkit_commons` | Shared ML Kit utility package required by ML Kit modules. | Declared; no direct usage in `lib/` currently |
| `image` | Image decode, resize, filters, transforms, and JPEG encoding for editor/export quality control. | Used in editor and export services |
| `opencv_dart` | OpenCV bindings for advanced image processing workflows. | Declared; no direct usage in `lib/` currently |
| `pdfium_flutter` | PDF rendering backend plugin for future/advanced PDF viewing/rendering. | Declared; appears in generated plugin registration |

### Development dependencies (`dev_dependencies`)

| Dependency | Why it is in the app | Current usage status |
|---|---|---|
| `flutter_test` | Flutter’s official test framework for widget/unit tests. | Used by `test/widget_test.dart` |
| `flutter_lints` | Recommended lint rules enforced via `analysis_options.yaml`. | Used for static analysis/linting configuration |

## Notes

- Packages marked “declared; no direct usage in `lib/` currently” are present in the project but are not yet imported in active Dart app code.
- This audit reflects the current branch state at the time of creation.
