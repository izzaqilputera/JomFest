import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  JomFest – Centralised Theme
//  Generated from: register_screen.dart,
//  admin_dashboard.dart, auth_gate.dart,
//  event_detail_screen.dart, home_screen.dart,
//  login_screen.dart, organizer_dashboard.dart,
//  organizer_registration.dart, payment_screen.dart
// ─────────────────────────────────────────────

// ══════════════════════════════════════════════
//  1. COLOUR PALETTE
// ══════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ── Brand / Primary ──────────────────────────
  static const Color primary        = Color(0xFF3B795E); // medium green from palette
  static const Color secondary      = Color(0xFFB1E2C6); // lightest green from palette
  static const Color primaryLight   = Color(0xFF57A683); // light green from palette
  static const Color primarySurface = Color(0x333B795E); // soft green tint
  static const Color primaryBorder  = Color(0xFF3B795E); // selected border

  // ── Backgrounds ──────────────────────────────
  static const Color scaffoldBg     = Color(0xFF121212); // app-wide scaffold bg (dark)
  static const Color white          = Color(0xFFECECEC); // soft white for dark mode
  static const Color black          = Color(0xFF000000);
  static const Color transparent    = Colors.transparent;
  static const Color cardBg         = Color(0xBF000000); // 75% black containers/cards

  // ── Text ─────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF5F5F5); // headings, body bold
  static const Color textSecondary  = Color(0xFFB0B0B0); // grey labels / hints
  static const Color textHint       = Color(0xFFBDBDBD);
  // (Grey shades used inline: Colors.grey[500], [600], [700] — kept as-is via Flutter)

  // ── Neutral greys ───────────────────────────
  static const Color grey           = Color(0xFF9E9E9E);
  static const Color grey300        = Color(0xFFE0E0E0);
  static const Color grey400        = Color(0xFFBDBDBD);
  static const Color grey500        = Color(0xFF9E9E9E);
  static const Color grey600        = Color(0xFF757575);
  static const Color grey700        = Color(0xFF616161);

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

  // ── Dividers & Borders ───────────────────────
  static const Color divider        = Color(0xFF2A2A2A);
  static const Color dividerLight   = Color(0xFF242424);
  static const Color inputFill      = Color(0xFF1F1F1F);

  // ── AppBar ───────────────────────────────────
  static const Color appBarBg       = Color(0xFF111214);
  static const Color appBarFg       = Color(0xFFB0B0B0); // grey foreground
  static const Color appBarTabActive   = Color(0xFFE0E0E0); // light grey for active
  static const Color appBarTabInactive = Color(0xFF757575); // dark grey for inactive

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
  static const TextStyle screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // ── Section / Card Title ──────────────────────
  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle listItemTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // ── AppBar Title ──────────────────────────────
  static const TextStyle appBarTitle = TextStyle(
    fontWeight: FontWeight.bold,
    color: AppColors.appBarFg,
  );

  // ── Labels (form fields, section headers) ────
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ── Body / Regular ────────────────────────────
  static const TextStyle bodyRegular = TextStyle(
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

  static const TextStyle captionBold = TextStyle(
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
      color: Colors.black.withOpacity(0.04),
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

  /// Standard white card with grey border
  static BoxDecoration card({Color? borderColor}) =>
      BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: borderColor ?? AppColors.divider),
      );

  /// Lavender surface (input fill, stat cards, chips)
  static BoxDecoration surface = BoxDecoration(
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
        AppColors.primary.withOpacity(0.8),
        AppColors.primaryLight.withOpacity(0.6),
      ],
    ),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(AppRadius.card),
      topRight: Radius.circular(AppRadius.card),
    ),
  );

  /// Verified-card border (green tint)
  static BoxDecoration verifiedCard = BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(
      color: AppColors.success.withOpacity(0.3),
    ),
  );

  /// Recommended card — primary tint border
  static BoxDecoration recommendedCard = BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(
      color: AppColors.primary.withOpacity(0.3),
    ),
  );

  /// Input field
  static BoxDecoration inputField = BoxDecoration(
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
    foregroundColor: AppColors.black,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    ),
    elevation: 0,
  );

  /// Success / Approve button
  static ButtonStyle success = ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: AppColors.black,
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

  /// Sign-out outlined button (purple tint)
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

      // Seed colour drives the entire M3 colour scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.black,
        surface: AppColors.scaffoldBg,
        onSurface: AppColors.textPrimary,
      ),

      scaffoldBackgroundColor: AppColors.scaffoldBg,

      // ── AppBar ───────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBg,
        foregroundColor: AppColors.appBarFg,
        elevation: 0,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),

      // ── TabBar ───────────────────────────────
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.white,
        labelColor: AppColors.appBarTabActive,
        unselectedLabelColor: AppColors.appBarTabInactive,
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
        foregroundColor: AppColors.black,
      ),

      // ── InputDecoration ──────────────────────
      inputDecorationTheme: InputDecorationTheme(
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
        hintStyle: const TextStyle(color: AppColors.textHint),
      ),

      // ── Card ─────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // ── Dialog ───────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        backgroundColor: AppColors.cardBg,
      ),

      // ── SnackBar ─────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: AppColors.black),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // ── Divider ──────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
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
          foregroundColor: AppColors.white,
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
        color: AppColors.cardBg,
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
        backgroundColor: AppColors.cardBg,
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