# App Testing & Verification Guide

## Pre-Launch Checklist

### ✅ Code Quality
- [x] No compilation errors
- [x] No lint warnings
- [x] Proper imports used
- [x] Constants centralized
- [x] Code well-organized

### ✅ UI/UX
- [x] Light mode colors correct
- [x] Dark mode colors correct
- [x] Typography consistent
- [x] Spacing uniform
- [x] Touch targets adequate (48x48 minimum)

### ✅ Performance
- [x] No unused variables
- [x] Efficient widget rebuilds
- [x] Proper use of const constructors
- [x] No memory leaks

## Running & Testing the App

## New Regression Tests (PDF Viewer + Draft Share)

### PDF Viewer Performance and Zoom
- [ ] Open an external PDF from Android share/open-with sheet.
  - Expected: viewer opens smoothly without long freeze.
- [ ] Open an exported PDF from Files -> Exported.
  - Expected: pages render quickly and scroll smoothly.
- [ ] Pinch with two fingers to zoom in/out.
  - Expected: smooth zoom interaction.
- [ ] Tap zoom in/out toolbar actions.
  - Expected: zoom level changes immediately and remains stable.

### Draft Share Smart Behavior
- [ ] Create/update a draft and tap Share.
  - Expected: one visible progress flow appears, then share sheet opens.
- [ ] Share same draft again without any changes.
  - Expected: skips export step and opens share faster using existing PDF.
- [ ] Change draft content (crop/filter/rotate/page order) and tap Share.
  - Expected: re-exports new PDF, then opens share sheet.
- [ ] Rename draft and tap Share.
  - Expected: treated as changed signature and exported PDF metadata refreshes.

### Failure/Edge Cases
- [ ] Delete previously exported PDF file manually, then share unchanged draft.
  - Expected: app detects missing cached export and re-exports automatically.
- [ ] Corrupt/missing page source in a draft.
  - Expected: app shows failure feedback and does not crash.

### Step 1: Initial Setup
```bash
cd <project-root>

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Check for issues
flutter analyze
```

### Step 2: Run on Device/Emulator
```bash
# List available devices
flutter devices

# Run on default device
flutter run

# Run on specific device
flutter run -d <device-id>

# Run with debug banner removed
flutter run

# Hot reload (press 'r' in terminal)
# Hot restart (press 'R' in terminal)
```

### Step 3: Visual Testing Checklist

#### Light Mode ✅
- [ ] Tap the app icon to verify it's showing light theme
- [ ] Check if all text is readable (dark text on light background)
- [ ] Verify the gradient on action cards
- [ ] Check spacing and alignment
- [ ] Ensure icons are visible
- [ ] Verify recent documents section
- [ ] Check feature tiles in Quick Tools

#### Dark Mode ✅
- [ ] Open device settings and enable dark mode
- [ ] App should automatically switch to dark theme
- [ ] Check if all text is readable (light text on dark background)
- [ ] Verify the gradient colors are appropriate
- [ ] Ensure proper contrast on all elements
- [ ] Check icon visibility
- [ ] Verify recent documents section colors

#### Interactive Elements ✅
- [ ] Tap "Take a Photo" button
  - Expected: SnackBar appears with "Take Photo feature coming soon!"
- [ ] Tap "Import Gallery" button
  - Expected: SnackBar appears with "Import Gallery feature coming soon!"
- [ ] Tap any tool tile (Edit, Organize, Merge, Compress)
  - Expected: SnackBar shows which tool was tapped
- [ ] Tap any document in Recent Documents
  - Expected: SnackBar shows document name
- [ ] Tap delete icon (×) on a document
  - Expected: Document is removed and SnackBar confirms
- [ ] Tap "View All" button
  - Expected: SnackBar appears
- [ ] Tap settings icon in app bar
  - Expected: SnackBar appears

#### Responsive Design ✅
- [ ] Test on phone (vertical orientation)
- [ ] Rotate phone to landscape
  - Expected: Layout adjusts properly
- [ ] Test on tablet (if available)
  - Expected: Content scales appropriately
- [ ] Verify scrolling works smoothly
- [ ] Check if all content is accessible without scrolling on larger screens

#### Animation & Polish ✅
- [ ] AppBar should pin to top when scrolling
- [ ] Shadows should appear on cards
- [ ] Colors should blend smoothly in gradients
- [ ] Text should render smoothly
- [ ] No janky animations

## Device-Specific Testing

### Android Testing
```bash
# Run on Android emulator
flutter emulators --launch android-emulator
flutter run

# Test on physical device
adb devices
flutter run -d <device-id>
```

**Platforms to test:**
- [ ] Android 7.0+
- [ ] Android 10+
- [ ] Android 12+ (with Material You theming)

### iOS Testing
```bash
# Run on iOS simulator
flutter run -d "iPhone 14"

# Run on physical device
# (Requires setup in Xcode)
flutter run
```

**Platforms to test:**
- [ ] iOS 12+
- [ ] iOS 15+
- [ ] iPhone Pro/Pro Max (notch)

## Performance Testing

### Memory Usage
```bash
# Run with DevTools
flutter pub global activate devtools
devtools

# Then connect your app to DevTools for memory profiling
```

### Frame Rate Testing
- [ ] Scroll through all sections smoothly
- [ ] No frame drops on animations
- [ ] Consistent 60 FPS (or 120 FPS on high-refresh phones)

### Load Testing
- [ ] App starts in < 2 seconds
- [ ] No UI freezing
- [ ] Smooth navigation

## Widget Tree Verification

Open DevTools and check:
- [ ] Widget tree is properly structured
- [ ] No duplicate widgets
- [ ] Proper use of Scaffold
- [ ] Correct Theme application

## Color Verification

### Light Theme Verification
```
Background: #FFFBFE (very light - almost white)
Surface: #FAF8FC (card background)
Primary: #6750A4 (gradient start)
Text (primary): #1C1B1F (dark text)
Text (secondary): #49454E (medium gray)
```

### Dark Theme Verification
```
Background: #1C1B1F (very dark - almost black)
Surface: #2B2A2F (card background)
Primary: #6750A4 (gradient start)
Text (primary): #FFFBFE (white text)
Text (secondary): #CAC7D0 (light gray)
```

## Expected Screen Sections (Top to Bottom)

### Section 1: App Bar
- App title "PhotoToPDF"
- Settings icon in top right
- Pinned to top when scrolling

### Section 2: Welcome Banner
- Large heading: "Welcome to PhotoToPDF"
- Subheading: "Convert your photos into professional PDF documents"

### Section 3: Action Cards (2 columns)
- Left: "Take Photo" (purple gradient)
- Right: "Import Gallery" (green gradient)
- Both have icons and descriptions

### Section 4: Quick Tools (horizontal scroll)
- Edit PDF (purple)
- Organize (green)
- Merge (orange)
- Compress (blue)

### Section 5: Recent Documents
- "View All" button in top right
- List of 3 documents with:
  - PDF icon
  - Title
  - Date
  - Page count
  - Delete button

### Section 6: Why Choose PhotoToPDF?
- Feature row 1: Lightning Fast
- Feature row 2: High Quality
- Feature row 3: Easy to Use

## Debugging Tips

### Basic Debugging
```dart
// Add to any widget to see rebuild count
@override
Widget build(BuildContext context) {
  debugPrint('Building SomeWidget');
  return ...
}
```

### Color Debugging
```dart
// Visualize all widgets with borders
void main() {
  debugPaintSizeEnabled = true;
  runApp(const MyApp());
}
```

### Performance Issues
- Check DevTools → Performance tab
- Look for red flags in frame time
- Profile with `flutter run --profile`

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| App crashes on startup | Check `main.dart` imports |
| Widgets not displaying | Verify `home_screen.dart` imports |
| Colors wrong | Check `app_colors.dart` values |
| Theme not switching | Verify `ThemeMode` in `main.dart` |
| Scrolling laggy | Profile with DevTools |
| Animations jittery | Check for expensive operations |

## Final Verification Checklist

Before considering the home screen complete:

### Functionality
- [x] All buttons are clickable
- [x] No crashes or errors
- [x] SnackBars display correctly
- [x] Documents can be deleted
- [x] Scrolling works smoothly

### Design
- [x] Light theme looks professional
- [x] Dark theme is comfortable in low light
- [x] All text is readable
- [x] Spacing is consistent
- [x] Colors match design system

### Code Quality
- [x] No compilation errors
- [x] No warnings in analyzer
- [x] Code is well-organized
- [x] Components are reusable
- [x] Future phases are planned

### Documentation
- [x] PROJECT_STRUCTURE.md created
- [x] QUICK_START.md created
- [x] CODE_STRUCTURE.md created
- [x] This guide created

## Next Steps After Verification

Once the home screen is verified working:

1. **Implement Camera/Gallery** (Phase 2)
2. **Create PDF Generation** (Phase 3)
3. **Add PDF Editing Tools** (Phase 4)
4. **Enhance with ML Kit** (Phase 5)

---

**Status: ✅ Home Screen Complete & Ready to Test**

Run `flutter run` and enjoy your beautiful PhotoToPDF app! 🎉
