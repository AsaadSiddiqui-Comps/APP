# File Structure & Code Organization Guide

## Complete Project Structure

```
Docly/
├── android/                          # Android platform code
├── ios/                              # iOS platform code
├── lib/
│   ├── config/
│   │   └── theme.dart               # Theme system
│   │       ├── Light Theme Definition
│   │       ├── Dark Theme Definition
│   │       └── Material 3 Components
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart      # Color palette
│   │   │   │   ├── Primary Colors
│   │   │   │   ├── Light/Dark Theme Colors
│   │   │   │   ├── Gradient Definitions
│   │   │   │   └── Status Colors
│   │   │   │
│   │   │   ├── app_constants.dart   # App constants
│   │   │   │   ├── String Constants
│   │   │   │   ├── Spacing Values
│   │   │   │   ├── Border Radius
│   │   │   │   └── Animation Durations
│   │   │   │
│   │   │   └── constants.dart       # Exports file
│   │   │
│   │   ├── services/
│   │   │   └── external_file_open_service.dart # External PDF open bridge
│   │   └── utilities/               # Utility functions (future)
│   │
│   ├── features/
│   │   ├── home/
│   │   │   ├── screens/
│   │   │   │   └── home_screen.dart
│   │   │   │       ├── Hero Section
│   │   │   │       ├── Action Cards
│   │   │   │       ├── Quick Tools
│   │   │   │       ├── Recent Documents
│   │   │   │       ├── Features Highlight
│   │   │   │       └── Event Handlers
│   │   │   │
│   │   │   └── widgets/
│   │   │       ├── action_card.dart
│   │   │       │   ├── Gradient Support
│   │   │       │   ├── Icon Display
│   │   │       │   └── Tap Animation
│   │   │       │
│   │   │       ├── recent_document_card.dart
│   │   │       │   ├── Document Info
│   │   │       │   ├── Date/Pages Display
│   │   │       │   └── Delete Function
│   │   │       │
│   │   │       ├── feature_tile.dart
│   │   │       │   ├── Icon Container
│   │   │       │   └── Label Text
│   │   │       │
│   │   │       └── widgets.dart     # Exports file
│   │   │
│   │   ├── editor/
│   │   │   └── screens/
│   │   │       └── editor_coming_soon_screen.dart # Edit, crop, rotate, filter flow
│   │   ├── export/
│   │   │   ├── screens/
│   │   │   │   └── document_export_screen.dart    # Export options and progress
│   │   │   └── services/
│   │   │       └── document_export_service.dart   # Background PDF/images export
│   │   ├── documents/
│   │   │   ├── data/
│   │   │   │   ├── document_draft_store.dart      # Draft index persistence
│   │   │   │   └── document_storage_service.dart   # Draft/export storage ops
│   │   │   └── models/
│   │   │       └── document_draft.dart            # Draft model + export cache metadata
│   │   └── files/
│   │       └── screens/
│   │           ├── files_screen.dart              # Draft/Exported manager + smart share flow
│   │           └── pdf_viewer_screen.dart         # Fast PDF viewer + pinch zoom
│   │
│   └── main.dart                    # Entry point (35 lines)
│       ├── MyApp (StatefulWidget)
│       ├── Theme Configuration
│       ├── Dark/Light Support
│       └── Home Screen Route
│
├── pubspec.yaml                     # Dependencies
├── analysis_options.yaml            # Analysis rules
├── PROJECT_STRUCTURE.md             # This guide
└── QUICK_START.md                   # Quick start guide
```

## Detailed Code Breakdown

### 1. main.dart (Entry Point)
**Lines: ~35**
**Responsibility:** App initialization and theme management

```dart
MyApp (StatefulWidget)
  ├── Theme Setup
  │   ├── Light Theme (from AppTheme)
  │   └── Dark Theme (from AppTheme)
  └── Home Route → HomeScreen()
```

### 2. config/theme.dart (Theme System)
**Lines: ~150**
**Responsibility:** Material 3 design system

```dart
AppTheme (Static Class)
  ├── lightTheme → ThemeData
  │   ├── ColorScheme (light colors)
  │   ├── TextTheme (typography)
  │   ├── AppBarTheme
  │   ├── ElevatedButtonTheme
  │   └── InputDecorationTheme
  │
  └── darkTheme → ThemeData
      ├── ColorScheme (dark colors)
      ├── TextTheme (adjusted typography)
      ├── AppBarTheme
      ├── ElevatedButtonTheme
      └── InputDecorationTheme
```

### 3. core/constants/app_colors.dart
**Lines: ~50**
**Responsibility:** Centralized color definitions

```dart
AppColors (Static Class)
  ├── Primary Colors
  │   ├── primary (#6750A4)
  │   ├── primaryLight
  │   └── primaryDark
  │
  ├── Light Theme
  │   ├── lightBackground
  │   ├── lightSurface
  │   └── lightOnBackground
  │
  ├── Dark Theme
  │   ├── darkBackground
  │   ├── darkSurface
  │   └── darkOnBackground
  │
  └── Special Colors
      ├── Gradients
      ├── Status (success, error, warning)
      └── Disabled/Divider states
```

### 4. core/constants/app_constants.dart
**Lines: ~50**
**Responsibility:** Text and sizing constants

```dart
AppConstants (Static Class)
  ├── Strings
  │   ├── homeTitle
  │   ├── UI Labels
  │   └── Button text
  │
  ├── Spacing Values
  │   ├── spacingXSmall (4)
  │   ├── spacingSmall (8)
  │   ├── spacingMedium (16)
  │   ├── spacingLarge (24)
  │   └── spacingXLarge (32)
  │
  ├── Border Radius
  │   ├── radiusSmall (8)
  │   ├── radiusMedium (12)
  │   ├── radiusLarge (16)
  │   └── radiusXLarge (24)
  │
  ├── Icon Sizes
  │   ├── iconSizeSmall (20)
  │   ├── iconSizeMedium (24)
  │   ├── iconSizeLarge (32)
  │   └── iconSizeXLarge (48)
  │
  └── Animation Durations
      ├── animationDuration (300ms)
      └── slowAnimationDuration (500ms)
```

### 5. features/home/screens/home_screen.dart
**Lines: ~350**
**Responsibility:** Main landing page UI and interactions

```dart
HomeScreen (StatefulWidget)
  └── _HomeScreenState
      ├── Build Method
      │   ├── CustomScrollView + SliverAppBar
      │   │   ├── App Bar (title + settings)
      │   │   └── Hero Section (welcome message)
      │   │
      │   ├── Action Cards Section
      │   │   ├── Take Photo Card (gradient)
      │   │   └── Import Gallery Card (gradient)
      │   │
      │   ├── Quick Tools Section
      │   │   ├── Edit PDF Tile
      │   │   ├── Organize Tile
      │   │   ├── Merge Tile
      │   │   └── Compress Tile
      │   │
      │   ├── Recent Documents Section
      │   │   ├── View All Button
      │   │   ├── Document 1
      │   │   ├── Document 2
      │   │   └── Document 3
      │   │
      │   └── Features Highlight Section
      │       ├── Lightning Fast
      │       ├── High Quality
      │       └── Easy to Use
      │
      ├── State Variables
      │   └── recentDocuments[] (mock data)
      │
      └── Event Handlers
          ├── _handleTakePhoto()
          ├── _handleImportGallery()
          ├── _handleOpenTools()
          ├── _handleOpenDocument()
          ├── _handleDeleteDocument()
          ├── _handleViewAll()
          └── _handleSettings()
```

### 6. features/files/screens/files_screen.dart
**Responsibility:** Draft and exported file management

Key responsibilities:
- Draft/Exported bucket switching and sorting
- Quick actions: edit, export, share, rename, delete
- Smart draft share path:
  - Reuse previous exported PDF when draft signature is unchanged
  - Export first and then share when draft changed or no cached export exists
- Single progress overlay for export-then-share flow

### 7. features/files/screens/pdf_viewer_screen.dart
**Responsibility:** In-app PDF viewing and sharing

Key responsibilities:
- Fast file-based PDF rendering
- Pinch-to-zoom support
- Toolbar zoom in/zoom out actions
- Share and open externally actions

### 8. features/documents/models/document_draft.dart
**Responsibility:** Draft document contract and persistence model

Key fields:
- `id`, `name`, `pagePaths`, `filterBasePaths`, `updatedAt`
- `exportedPdfPath` for last reusable exported PDF
- `exportedSignature` for change detection against current draft state

### 9. features/export/services/document_export_service.dart
**Responsibility:** Async export pipeline

Key responsibilities:
- Export pages to PDF with progress callbacks
- Export pages as image sequence
- Run heavy generation work off the UI path
- Provide a stable exported output path

### 10. features/home/widgets/action_card.dart
**Lines: ~80**
**Responsibility:** Gradient action buttons

```dart
ActionCard (StatelessWidget)
  ├── Properties
  │   ├── title: String
  │   ├── subtitle: String
  │   ├── icon: IconData
  │   ├── backgroundColor: Color
  │   ├── iconColor: Color
  │   ├── onTap: VoidCallback
  │   └── isGradient: bool
  │
  └── Build
      └── GestureDetector + Container
          ├── Gradient Background (optional)
          ├── Shadow Effect
          └── Column
              ├── Icon Container
              └── Text (title + subtitle)
```

### 11. features/home/widgets/recent_document_card.dart
**Lines: ~90**
**Responsibility:** Document list item display

```dart
RecentDocumentCard (StatelessWidget)
  ├── Properties
  │   ├── title: String
  │   ├── date: String
  │   ├── pages: String
  │   ├── onTap: VoidCallback
  │   └── onDelete: VoidCallback
  │
  └── Build
      └── Container
          └── Row
              ├── PDF Icon Container
              ├── Expanded Column
              │   ├── Title Text
              │   └── Info Row (date + pages)
              └── Delete Button
```

### 12. features/home/widgets/feature_tile.dart
**Lines: ~50**
**Responsibility:** Square tool buttons

```dart
FeatureTile (StatelessWidget)
  ├── Properties
  │   ├── label: String
  │   ├── icon: IconData
  │   ├── color: Color
  │   └── onTap: VoidCallback
  │
  └── Build
      └── Column
          ├── Icon Container
          │   └── Icon
          └── Label Text
```

## Data Flow

```
main.dart
  ↓
MyApp (theme setup)
  ↓
HomeScreen
  ├── Opens FilesScreen (Recent arrow)
  ├── Consumes external PDF intents via ExternalFileOpenService
  └── Opens PdfViewerScreen for external/opened PDFs

FilesScreen
  ├── Loads drafts from DocumentDraftStore
  ├── Resolves pages via DocumentStorageService
  ├── Opens EditorComingSoonScreen for editing/export
  └── Share Draft:
      ├── Build draft signature
      ├── Reuse cached PDF if unchanged
      ├── Else call DocumentExportService.exportPdf
      └── Share with one progress flow
```

## Dependency Injection Pattern

```
Constants/Colors/Theme
  ↓ (static access)
Any Screen/Widget
  ├── AppColors.primary
  ├── AppConstants.spacingLarge
  └── Theme.of(context).textTheme
```

## Future Expansion

```
lib/features/
├── home/          ✅ COMPLETE
├── gallery/       (phase 2)
│   ├── screens/
│   └── widgets/
├── pdf_generator/ (phase 3)
│   ├── screens/
│   ├── services/
│   └── models/
├── pdf_editor/    (phase 4)
│   ├── screens/
│   ├── services/
│   └── widgets/
└── settings/      (phase 5)
    ├── screens/
    └── widgets/
```

## Current Focus Modules

| Module | Purpose | Status |
|-----------|-------|--------|
| Home + Recent | App landing and recent drafts | ✅ Active |
| Editor | Crop/rotate/filter and draft editing | ✅ Active |
| Export | PDF/image export with progress | ✅ Active |
| Files | Draft/Exported browsing and actions | ✅ Active |
| PDF Viewer | Fast in-app viewer with zoom | ✅ Active |
| Documents Store | Draft index + storage metadata | ✅ Active |

## Latest Behavioral Notes (April 2026)

- In-app PDF viewing now uses fast file-based rendering for better responsiveness.
- Pinch zoom is supported in viewer, plus explicit zoom controls.
- Draft share now avoids unnecessary export by reusing previous exported PDF if unchanged.
- If draft changed or cached PDF is missing, export runs first and then share opens.
- Export/share user feedback is presented through a single progress flow.

## Architecture Benefits

✅ **Scalability** - Easy to add new features
✅ **Maintainability** - Clear separation of concerns
✅ **Reusability** - Components used across screens
✅ **Consistency** - Centralized theme and constants
✅ **Performance** - Efficient widget building
✅ **Testability** - Pure functions and widgets

---

For implementation examples, see [QUICK_START.md](QUICK_START.md)
