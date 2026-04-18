# PhotoToPDF - Project Structure Guide

## Project Overview

PhotoToPDF is a modern Flutter application for converting photos into PDF documents with professional editing capabilities. The app supports both light and dark themes with a beautiful, intuitive user interface.

## Project Structure

```
lib/
├── config/
│   └── theme.dart                 # Light and Dark theme configurations
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        # All color definitions
│   │   ├── app_constants.dart     # String constants and sizing
│   │   └── constants.dart         # Constants exports
│   ├── services/
│   │   └── external_file_open_service.dart # Android intent bridge for external PDF open
│   └── utilities/                 # Utility functions (future)
├── features/
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart   # Main home screen implementation
│   │   └── widgets/
│   │       ├── action_card.dart        # Photo/Gallery action cards
│   │       ├── recent_document_card.dart # Recent documents display
│   │       ├── feature_tile.dart       # Quick tools tiles
│   │       └── widgets.dart            # Widgets exports
│   ├── tools/                   # PDF editing tools (future)
│   ├── gallery/                 # Photo gallery management (future)
│   ├── pdf_editor/              # PDF editing features (future)
│   └── files/
│       └── screens/
│           ├── files_screen.dart       # Draft/Exported manager with sort, quick actions, and hold menu
│           └── pdf_viewer_screen.dart  # Fast in-app PDF viewer (file-based rendering + pinch zoom)
├── features/
│   └── documents/
│       └── models/
│           └── document_draft.dart     # Draft model with export cache metadata
└── main.dart                    # App entry point

```

## File Descriptions

### Configuration & Theme

**`lib/config/theme.dart`**
- Defines Material 3 design system
- Light theme with neutral colors
- Dark theme with appropriate contrast
- Custom text styles and component themes
- Shared across all screens

**`lib/core/constants/app_constants.dart`**
- String constants for UI labels
- Spacing values for consistent padding/margins
- Border radius values for rounded corners
- Icon sizes
- Animation durations

**`lib/core/constants/app_colors.dart`**
- Color palette for light theme
- Color palette for dark theme
- Gradient definitions
- Status colors (success, error, warning)
- Opacity and divider colors

### Features - Home Screen

**`lib/features/home/screens/home_screen.dart`**
- Main landing screen of the application
- Section 1: Welcome banner with app description
- Section 2: Action cards for taking photo / importing gallery
- Section 3: Quick tools section (Edit, Organize, Merge, Compress)
- Section 4: Recent documents display with mock data
- Section 5: App features highlight
- Mock data management and state handling

**`lib/features/home/widgets/action_card.dart`**
- Reusable component for primary actions
- Supports gradient backgrounds
- Icon display with background
- Title and subtitle text
- Shadow animation on tap
- Used for: Take Photo, Import Gallery

**`lib/features/home/widgets/recent_document_card.dart`**
- Displays recent PDF documents
- Shows title, date, and page count
- Icon-based visual indicator
- Delete functionality
- Tap-to-open handling

**`lib/features/home/widgets/feature_tile.dart`**
- Small square tiles with icon and label
- Horizontal scrolling list
- Used for quick tool access
- Customizable colors
- Space-efficient design

**`lib/main.dart`**
- Application entry point
- MaterialApp configuration
- Theme switching support (light/dark)
- Routes to HomeScreen

## Key Features Implemented

### ✅ Files Page + In-App PDF Viewer
- Added dedicated Files page with bucket switch:
   - Drafts
   - Exported
- Added sorting options:
   - Date
   - Name
- Added long-press and quick-action menus with icons for:
   - Edit
   - Export this scan
   - Share
   - Add signature (placeholder)
   - Rename
   - Delete
- Added in-app PDF viewer screen for exported files.
- Viewer now uses fast file-based PDF rendering for smoother open performance (especially external PDFs).
- Added pinch zoom and explicit zoom controls in PDF viewer.
- Added external PDF intent bridge so Docly can appear in Android open/share sheet for PDF files.

### ✅ Smart Draft Share/Export Flow
- Draft sharing behavior is now change-aware:
   - Unchanged draft + valid previous exported PDF => direct share (no re-export).
   - New/changed draft => export first, then share.
- Single visible progress flow for share/export path (one progress bar UX).
- Draft persistence includes export metadata used for reuse decisions:
   - `exportedPdfPath`
   - `exportedSignature`

### ✅ Light & Dark Mode Support
- Complete theme system with Material 3 design
- Automatic theme switching with SystemThemeMode option
- All colors properly defined for both themes
- Smooth transitions between themes

### ✅ Beautiful Modern UI
- Gradient backgrounds on action cards
- Proper spacing and alignment
- Reusable widget components
- Smooth animations and interactions
- Professional color palette

### ✅ Well-Organized Code
- Feature-based folder structure
- Separated concerns (screens, widgets, config, constants)
- Reusable components
- Centralized color and constant definitions
- Easy to scale and maintain

## Packages Added

### Image & File Handling
- `image_picker: ^1.0.7` - For camera and gallery selection
- `permission_handler: ^11.4.4` - For app permissions

### PDF Processing
- `pdf: ^3.10.8` - PDF document creation
- `printing: ^5.11.3` - PDF preview and printing
- `syncfusion_flutter_pdfviewer` - Fast in-app PDF viewing with pinch-to-zoom

### ML Kit Integration
- `google_mlkit_commons: ^0.7.0` - Google ML Kit commons library

## Future Implementation Plans

### Phase 2: Photo Capture & Import
- Implement camera functionality
- Gallery image selection
- Image preview and thumbnails
- Batch photo selection

### Phase 3: PDF Creation
- Convert selected photos to PDF
- Image compression options
- Page layout customization
- PDF preview

### Phase 4: PDF Tools
- PDF editing capabilities
- Page reordering
- Page deletion
- PDF merging
- Compression

### Phase 5: Advanced Features
- OCR using ML Kit
- Document scanning enhancement
- Cloud storage integration
- Document sharing

## Color Scheme

**Primary Color**: #6750A4 (Purple)
**Secondary Color**: #625B71 (Gray)
**Accent Color**: #52B788 (Green)
**Light Background**: #FFFBFE
**Dark Background**: #1C1B1F

## Font & Typography

All text uses the system font with proper styling:
- Display size: 36-57px for large headings
- Headline size: 24-28px for section titles
- Body size: 14-16px for regular text
- Label size: 12px for descriptions

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run -d <device>
   ```

3. The app will display the beautiful home screen with all features

## Customization

To customize the app:

**Colors**: Edit `lib/core/constants/app_colors.dart`
**Strings**: Edit `lib/core/constants/app_constants.dart`
**Spacing**: Modify constants in `app_constants.dart`
**Theme**: Update `lib/config/theme.dart`

## Responsive Design

The layout is responsive and optimizes for:
- Mobile phones (default)
- Tablets (flexible widgets)
- Landscape orientation
- Different screen sizes

## Future Considerations

- State management (Provider or Riverpod)
- Local database for document history
- API integration for cloud features
- Testing suite
- App icon and splash screen
