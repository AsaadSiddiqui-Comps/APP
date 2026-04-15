# File Structure & Code Organization Guide

## Complete Project Structure

```
Docly/
├── android/                          # Android platform code
├── ios/                              # iOS platform code
├── lib/
│   ├── config/
│   │   └── theme.dart               # Theme system (150+ lines)
│   │       ├── Light Theme Definition
│   │       ├── Dark Theme Definition
│   │       └── Material 3 Components
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart      # Color palette (50+ lines)
│   │   │   │   ├── Primary Colors
│   │   │   │   ├── Light/Dark Theme Colors
│   │   │   │   ├── Gradient Definitions
│   │   │   │   └── Status Colors
│   │   │   │
│   │   │   ├── app_constants.dart   # App constants (50+ lines)
│   │   │   │   ├── String Constants
│   │   │   │   ├── Spacing Values
│   │   │   │   ├── Border Radius
│   │   │   │   └── Animation Durations
│   │   │   │
│   │   │   └── constants.dart       # Exports file
│   │   │
│   │   └── utilities/               # Utility functions (future)
│   │
│   ├── features/
│   │   ├── home/
│   │   │   ├── screens/
│   │   │   │   └── home_screen.dart (350+ lines)
│   │   │   │       ├── Hero Section
│   │   │   │       ├── Action Cards
│   │   │   │       ├── Quick Tools
│   │   │   │       ├── Recent Documents
│   │   │   │       ├── Features Highlight
│   │   │   │       └── Event Handlers
│   │   │   │
│   │   │   └── widgets/
│   │   │       ├── action_card.dart (80+ lines)
│   │   │       │   ├── Gradient Support
│   │   │       │   ├── Icon Display
│   │   │       │   └── Tap Animation
│   │   │       │
│   │   │       ├── recent_document_card.dart (90+ lines)
│   │   │       │   ├── Document Info
│   │   │       │   ├── Date/Pages Display
│   │   │       │   └── Delete Function
│   │   │       │
│   │   │       ├── feature_tile.dart (50+ lines)
│   │   │       │   ├── Icon Container
│   │   │       │   └── Label Text
│   │   │       │
│   │   │       └── widgets.dart     # Exports file
│   │   │
│   │   ├── tools/                   # PDF tools (phase 2)
│   │   ├── gallery/                 # Gallery management (phase 2)
│   │   └── pdf_editor/              # PDF editing (phase 3)
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

### 6. features/home/widgets/action_card.dart
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

### 7. features/home/widgets/recent_document_card.dart
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

### 8. features/home/widgets/feature_tile.dart
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
  ├── Uses: AppTheme (from config)
  ├── Uses: AppColors (from constants)
  ├── Uses: AppConstants (from constants)
  └── Renders:
      ├── ActionCard (widget)
      ├── FeatureTile (widget)
      ├── RecentDocumentCard (widget)
      └── Event handlers (future implementation)
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

## Lines of Code Summary

| Component | Lines | Status |
|-----------|-------|--------|
| main.dart | ~35 | ✅ Done |
| theme.dart | ~150 | ✅ Done |
| app_colors.dart | ~50 | ✅ Done |
| app_constants.dart | ~50 | ✅ Done |
| home_screen.dart | ~350 | ✅ Done |
| action_card.dart | ~80 | ✅ Done |
| recent_document_card.dart | ~90 | ✅ Done |
| feature_tile.dart | ~50 | ✅ Done |
| **Total** | **~855** | **✅ Complete** |

## Architecture Benefits

✅ **Scalability** - Easy to add new features
✅ **Maintainability** - Clear separation of concerns
✅ **Reusability** - Components used across screens
✅ **Consistency** - Centralized theme and constants
✅ **Performance** - Efficient widget building
✅ **Testability** - Pure functions and widgets

---

For implementation examples, see [QUICK_START.md](QUICK_START.md)
