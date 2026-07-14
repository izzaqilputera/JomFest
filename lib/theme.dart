import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  JomFest – Centralised Theme
//  Supports Light / Dark / System modes.
//  Themeable colours below are getters that
//  resolve against AppColors.isDark, which the
//  root MaterialApp keeps in sync with the
//  active ThemeMode (see main.dart).
// ─────────────────────────────────────────────

// ══════════════════════════════════════════════
//  0. THEME CONTROLLER (mode + persistence)
// ══════════════════════════════════════════════

class ThemeController {
  ThemeController._();

  static const String _prefsKey = 'theme_mode';

  /// Current app-wide theme mode. The root app listens to this.
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Load the saved preference at startup (defaults to dark).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = _decode(prefs.getString(_prefsKey));
    } catch (_) {
      mode.value = ThemeMode.dark;
    }
  }

  /// Update and persist the selected mode.
  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(m));
    } catch (_) {
      // Persistence is best-effort; the in-memory value still applies.
    }
  }

  static ThemeMode _decode(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static String label(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

// ══════════════════════════════════════════════
//  1. COLOUR PALETTE
// ══════════════════════════════════════════════

class AppColors {
  AppColors._();

  /// Whether the app is currently rendering in dark mode.
  /// Kept in sync by the root MaterialApp builder.
  static bool isDark = true;

  /// Resolve a colour for the current brightness.
  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ── Brand / Primary ──────────────────────────
  static const Color primary        = Color(0xFF3B795E); // medium green from palette
  static const Color secondary      = Color(0xFFB1E2C6); // lightest green from palette
  static const Color primaryLight   = Color(0xFF57A683); // light green from palette
  static const Color primarySurface = Color(0x333B795E); // soft green tint
  static const Color primaryBorder  = Color(0xFF3B795E); // selected border

  // ── Backgrounds (themeable) ──────────────────
  static Color get scaffoldBg => _pick(const Color(0xFFF6F7F9), const Color(0xFF121212));
  static const Color white       = Color(0xFFECECEC); // soft white (on-colour text)
  static const Color black       = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  /// Primary card / container surface.
  static Color get cardBg     => _pick(const Color(0xFFFFFFFF), const Color(0xFF1A1A1A));
  /// Inner card surface (lists, menu rows).
  static Color get surfaceCard => _pick(const Color(0xFFFFFFFF), const Color(0xFF161616));
  /// Elevated surface (dialogs, sheets).
  static Color get surfaceAlt  => _pick(const Color(0xFFF1F3F5), const Color(0xFF1E1E1E));

  // ── Text (themeable) ─────────────────────────
  static Color get textPrimary   => _pick(const Color(0xFF14181F), const Color(0xFFF5F5F5));
  static Color get textSecondary => _pick(const Color(0xFF5B6470), const Color(0xFFB0B0B0));
  static Color get textHint      => _pick(const Color(0xFF9AA1AC), const Color(0xFFBDBDBD));

  // ── Neutral greys (work on both themes) ──────
  static const Color grey    = Color(0xFF9E9E9E);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);

  // ── Status – Success ─────────────────────────
  static const Color success        = Color(0xFF22C55E); // approved / free ticket
  static const Color successStrong  = Color(0xFF15803D);
  static const Color successLight   = Color(0xFF86EFAC);
  static const Color successSurface = Color(0x3322C55E);
  static const Color successNoteBg  = Color(0xFFF0FDF4);

  // ── Status – Warning / Pending ───────────────
  static const Color warning        = Colors.orange;   // pending badges
  static const Color warningSurface = Color(0x33FF9800);

  // ── Status – Error / Rejected ────────────────
  static const Color error          = Colors.red;
  static const Color errorSurface   = Color(0x33F44336);

  // ── Dividers & Borders (themeable) ───────────
  static Color get divider      => _pick(const Color(0xFFE2E5EA), const Color(0xFF2A2A2A));
  static Color get dividerLight => _pick(const Color(0xFFECEEF1), const Color(0xFF242424));
  static Color get inputFill    => _pick(const Color(0xFFEFF1F4), const Color(0xFF1F1F1F));

  // ── AppBar (themeable) ───────────────────────
  static Color get appBarBg          => _pick(const Color(0xFFFFFFFF), const Color(0xFF111214));
  static Color get appBarFg          => _pick(const Color(0xFF2A2F37), const Color(0xFFB0B0B0));
  static Color get appBarTabActive   => _pick(const Color(0xFF14181F), const Color(0xFFE0E0E0));
  static Color get appBarTabInactive => _pick(const Color(0xFF9AA1AC), const Color(0xFF757575));

  // ── Payment status colours ───────────────────
  static const Color maybank          = Color(0xFFFFD700);
  static const Color cimb             = Color(0xFF990000);
  static const Color rhb              = Color(0xFF003087);
  static const Color hlb              = Color(0xFF009639);
  static const Color bankIslam        = Color(0xFF006400);
  static const Color publicBank       = Color(0xFF003087);
  static const Color touchNGo         = Color(0xFF0066CC);
  static const Color grabPay          = Color(0xFF00B14F);
  static const Color boost            = Color(0xFFFF6600);
  static const Color shopeePay        = Color(0xFFEE4D2D);
}


// ══════════════════════════════════════════════
//  2. TYPOGRAPHY
// ══════════════════════════════════════════════

class AppTextStyles {
  AppTextStyles._();

  // ── Screen Titles ─────────────────────────────
  static TextStyle get screenTitle => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  // ── Section / Card Title ──────────────────────
  static TextStyle get cardTitle => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitleLarge => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get listItemTitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  // ── AppBar Title ──────────────────────────────
  static TextStyle get appBarTitle => TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.appBarFg,
      );

  // ── Labels (form fields, section headers) ────
  static TextStyle get fieldLabel => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ── Body / Regular ────────────────────────────
  static TextStyle get bodyRegular => TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 15,
    color: AppColors.grey600,
  );

  // ── Small / Caption ───────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: AppColors.grey500,
  );

  static TextStyle get captionBold => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static const TextStyle xsmall = TextStyle(
    fontSize: 12,
    color: AppColors.grey500,
  );

  // ── Badge / Chip Text ─────────────────────────
  static const TextStyle chipText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle chipTextOnPrimary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.black,
  );

  // ── Price ─────────────────────────────────────
  static const TextStyle priceLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle priceFree = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.success,
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  // ── Button ────────────────────────────────────
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // ── Stat / Counter ────────────────────────────
  static const TextStyle statCount = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 10,
    color: AppColors.grey,
  );

  // ── Recommendation match badge ────────────────
  static const TextStyle matchBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
}


// ══════════════════════════════════════════════
//  3. SHAPE / RADIUS TOKENS
// ══════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  static const double xs    = 6;
  static const double sm    = 8;
  static const double md    = 10;
  static const double lg    = 12;
  static const double xl    = 14;
  static const double xxl   = 16;
  static const double pill  = 20;
  static const double card  = 16;   // standard card
  static const double input = 12;   // text fields
  static const double button = 14;  // CTA buttons
  static const double chip  = 20;   // category / interest chips
  static const double badge = 20;   // status badges
  static const double avatar = 12;  // square avatar containers
  static const double dialog = 16;  // dialogs / sheets
}


// ══════════════════════════════════════════════
//  4. SPACING TOKENS
// ══════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 28;
  static const double huge = 32;
  static const double max  = 40;

  // Horizontal screen padding
  static const double screenH = 24;
  static const double screenV = 16;

  // Card internal padding
  static const EdgeInsets cardPadding =
  EdgeInsets.all(16);

  // List item padding
  static const EdgeInsets listPadding =
  EdgeInsets.all(16);

  // Chip padding
  static const EdgeInsets chipPadding =
  EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  // Badge padding
  static const EdgeInsets badgePadding =
  EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  // Screen horizontal padding
  static const EdgeInsets screenPadding =
  EdgeInsets.symmetric(horizontal: 24);
}


// ══════════════════════════════════════════════
//  5. ELEVATION / SHADOWS
// ══════════════════════════════════════════════

class AppShadows {
  AppShadows._();

  /// Subtle bottom shadow — used on bottom nav bar
  static const List<BoxShadow> bottomBar = [
    BoxShadow(
      color: Color(0x14000000), // black ~8 %
      blurRadius: 10,
      offset: Offset(0, -4),
    ),
  ];

  /// Standard card shadow
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}


// ══════════════════════════════════════════════
//  6. COMPONENT DECORATIONS (reusable BoxDecoration)
// ══════════════════════════════════════════════

class AppDecorations {
  AppDecorations._();

  /// Standard card with themed border
  static BoxDecoration card({Color? borderColor}) =>
      BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: borderColor ?? AppColors.divider),
      );

  /// Green-tinted surface (input fill, stat cards, chips)
  static BoxDecoration get surface => BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      );

  /// Primary gradient — used on hero / header sections
  static const BoxDecoration primaryGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primaryLight],
    ),
  );

  /// Top-rounded gradient — used on event image placeholders
  static BoxDecoration eventImageGradient = BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.primary.withValues(alpha: 0.8),
        AppColors.primaryLight.withValues(alpha: 0.6),
      ],
    ),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(AppRadius.card),
      topRight: Radius.circular(AppRadius.card),
    ),
  );

  /// Verified-card border (green tint)
  static BoxDecoration get verifiedCard => BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      );

  /// Recommended card — primary tint border
  static BoxDecoration get recommendedCard => BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      );

  /// Input field
  static BoxDecoration get inputField => BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.input),
      );

  /// Success surface
  static BoxDecoration successSurface = BoxDecoration(
    color: AppColors.successSurface,
    borderRadius: BorderRadius.circular(AppRadius.pill),
  );

  /// Warning / Pending surface
  static BoxDecoration warningSurface = BoxDecoration(
    color: AppColors.warningSurface,
    borderRadius: BorderRadius.circular(AppRadius.pill),
  );

  /// Error / Rejected surface
  static BoxDecoration errorSurface = BoxDecoration(
    color: AppColors.errorSurface,
    borderRadius: BorderRadius.circular(AppRadius.pill),
  );

  /// Error message banner
  static BoxDecoration errorBanner = BoxDecoration(
    color: AppColors.errorSurface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );

  /// Security / success info note
  static BoxDecoration successNote = BoxDecoration(
    color: AppColors.successNoteBg,
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );
}


// ══════════════════════════════════════════════
//  7. INPUT DECORATION THEME HELPER
// ══════════════════════════════════════════════

class AppInputDecoration {
  AppInputDecoration._();

  static InputDecoration of(
      String hint, {
        IconData? prefixIcon,
        Widget? suffix,
        int? maxLines,
      }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide:
        const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}


// ══════════════════════════════════════════════
//  8. BUTTON STYLES
// ══════════════════════════════════════════════

class AppButtonStyles {
  AppButtonStyles._();

  /// Primary filled button (Create Account, Sign In, Submit…)
  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    ),
    elevation: 0,
  );

  /// Success / Approve button
  static ButtonStyle success = ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: AppColors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  /// Outlined danger / Reject button
  static ButtonStyle danger = OutlinedButton.styleFrom(
    foregroundColor: AppColors.error,
    side: const BorderSide(color: AppColors.error),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  /// Outlined primary button (Verify, View IC…)
  static ButtonStyle outlinedPrimary = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  /// Sign-out outlined button
  static ButtonStyle signOut = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );

  /// Sign-out outlined button (red variant for rejected state)
  static ButtonStyle signOutRed = OutlinedButton.styleFrom(
    foregroundColor: AppColors.error,
    side: const BorderSide(color: AppColors.error),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );

  /// Standard button height
  static const double height = 52;
}


// ══════════════════════════════════════════════
//  9. ICON SIZES
// ══════════════════════════════════════════════

class AppIconSizes {
  AppIconSizes._();

  static const double xs   = 12;
  static const double sm   = 14;
  static const double md   = 16;
  static const double lg   = 18;
  static const double xl   = 24;
  static const double xxl  = 28;
  static const double hero = 40;
  static const double mega = 60;
  static const double stat = 24;   // stat-card icons
}


// ══════════════════════════════════════════════
//  10. GRADIENTS
// ══════════════════════════════════════════════

class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );

  static const LinearGradient primaryHorizontal = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
  );
}


// ══════════════════════════════════════════════
//  11. FULL MATERIALAPP THEME
// ══════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        surface: const Color(0xFFF6F7F9),
        onSurface: const Color(0xFF14181F),
      ),

      scaffoldBackgroundColor: const Color(0xFFF6F7F9),

      // ── AppBar ───────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF2A2F37),
        elevation: 0,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),

      // ── TabBar ───────────────────────────────
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: Color(0xFF14181F),
        unselectedLabelColor: Color(0xFF9AA1AC),
      ),

      // ── ElevatedButton ───────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.primary,
      ),

      // ── OutlinedButton ───────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.outlinedPrimary,
      ),

      // ── TextButton ───────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),

      // ── FloatingActionButton ─────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),

      // ── InputDecoration ──────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEFF1F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:
          const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9AA1AC)),
      ),

      // ── Card ─────────────────────────────────
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Color(0xFFE2E5EA)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // ── Dialog ───────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
      ),

      // ── SnackBar ─────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // ── Divider ──────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFECEEF1),
        thickness: 1,
        space: 1,
      ),

      // ── CircularProgressIndicator ────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // ── DatePicker ───────────────────────────
      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: AppColors.white,
        dayOverlayColor: WidgetStateProperty.all(
          AppColors.primarySurface,
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        onPrimary: AppColors.white,
      ),

      scaffoldBackgroundColor: const Color(0xFF121212),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Color(0xFFB0B0B0),
        elevation: 0,
      ),

      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.secondary,
        labelColor: Color(0xFFE0E0E0),
        unselectedLabelColor: Color(0xFF757575),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.secondary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.black,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2A2A2A),
        contentTextStyle: const TextStyle(color: AppColors.grey300),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
      ),

      datePickerTheme: DatePickerThemeData(
        headerBackgroundColor: AppColors.secondary,
        headerForegroundColor: AppColors.black,
        dayOverlayColor: WidgetStateProperty.all(
          AppColors.primarySurface,
        ),
      ),
    );
  }
}
