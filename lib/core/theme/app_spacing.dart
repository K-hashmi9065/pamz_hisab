/// Spacing scale constants (in logical pixels before ScreenUtil scaling).
/// Use `.w` / `.h` / `.r` from flutter_screenutil in actual widgets.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // --- Border Radii ---
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 100.0;

  // --- Icon Sizes ---
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // --- Tap Target (iOS HIG minimum 44x44pt) ---
  static const double minTapTarget = 44.0;

  // --- Card Elevation ---
  static const double cardElevation = 0.0; // Flat cards; border instead of shadow
  static const double modalElevation = 8.0;

  // --- Sidebar ---
  static const double sidebarWidth = 72.0; // collapsed icon rail
  static const double sidebarExpandedWidth = 220.0;
}
