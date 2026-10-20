import 'package:flutter/material.dart';

class AppTheme {
  // ── Responsive Breakpoints (Logical Pixels) ──────────────────────────────
  static const double desktopBreakpoint = 1200.0; // Desktop threshold (>= 1200px)
  static const double tabletBreakpoint = 768.0;   // Tablet threshold (768px - 1199px)
  static const double mobileBreakpoint = 0.0;     // Mobile threshold (< 768px)

  static const double breakpointSm = 600.0;   // Mobile / compact
  static const double breakpointMd = 900.0;   // Tablet / compact desktop
  static const double breakpointLg = 1200.0;  // Standard desktop
  static const double breakpointXl = 1600.0;  // Wide / ultrawide desktop

  /// Check whether the current context viewport is Desktop (>= 1200px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Check whether the current context viewport is Tablet (768px - 1199px).
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tabletBreakpoint && w < desktopBreakpoint;
  }

  /// Check whether the current context viewport is Mobile (< 768px).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  /// Width-based viewport helpers for LayoutBuilder constraints.
  static bool isDesktopWidth(double width) => width >= desktopBreakpoint;
  static bool isTabletWidth(double width) => width >= tabletBreakpoint && width < desktopBreakpoint;
  static bool isMobileWidth(double width) => width < tabletBreakpoint;

  /// Width threshold below which horizontal tabs convert to vertical sidebar.
  static const double tabBarSidebarThreshold = 800.0;

  /// Width threshold below which vertical sidebar converts to mobile dropdown/drawer.
  static const double tabBarDropdownThreshold = 550.0;

  /// Tab count at or above which vertical sidebar is preferred automatically.
  static const int tabCountSidebarThreshold = 4;

  // ── Sorour Official Brand Palette Tokens (Extracted from Brand Logo) ──────
  static const Color sorourNavy = Color(0xFF0F386A);      // Primary Dark Navy (Logotype & Official Reports)
  static const Color sorourDeepBlue = Color(0xFF074E8C);  // Deep Ocean Blue (Vessels & Maritime Accents)
  static const Color sorourCobalt = Color(0xFF0B68A6);    // Sorour Primary Brand Blue (Interface & Actions)
  static const Color sorourSky = Color(0xFF077DBE);       // Vibrant Sky Blue (Air Freight & Highlights)
  static const Color sorourIceBlue = Color(0xFF88B6D2);   // Ice Accent / Borders / Muted Accents
  static const Color sorourWatermarkTint = Color(0xFF3A5A80); // Neutral Monochrome Watermark Overlay
  static const Color sorourSurfaceTint = Color(0xFFF0F5FA);// Brand Subtle Surface Tint

  // ── Flat Color Palette ────────────────────────────────────────────────────
  static const Color charcoal = Color(0xFF2C3E50);
  static const Color cobalt = Color(0xFF3498DB);
  static const Color emerald = Color(0xFF27AE60);
  static const Color orange = Color(0xFFE67E22);
  static const Color crimson = Color(0xFFC0392B);
  static const Color cloudWhite = Color(0xFFECF0F1);

  // Flat Palette Aliases
  static const Color flatCharcoal = charcoal;
  static const Color flatCobalt = cobalt;
  static const Color flatEmerald = emerald;
  static const Color flatOrange = orange;
  static const Color flatCrimson = crimson;
  static const Color flatCloudWhite = cloudWhite;

  // ── Opacity Color Constants ───────────────────────────────────────────────
  // Pre-computed to avoid withOpacity() allocations on every build.
  static const Color cobaltLight = Color(0x143498DB);   // cobalt ~8%
  static const Color cobaltMedium = Color(0x263498DB);  // cobalt ~15%
  static const Color cobaltBorder = Color(0x663498DB);  // cobalt ~40%
  static const Color emeraldLight = Color(0x2E27AE60);  // emerald ~18%
  static const Color emeraldBorder = Color(0x6627AE60); // emerald ~40%
  static const Color orangeLight = Color(0x1AE67E22);   // orange ~10%
  static const Color crimsonLight = Color(0x14C0392B);  // crimson ~8%
  static const Color crimsonBorder = Color(0x66C0392B); // crimson ~40%
  static const Color charcoalSurface = Color(0x0A2C3E50); // charcoal ~4%

  // ── Dark Theme Color Constants (High-Contrast Desktop Slate — WCAG AA Compliant) ─
  static const Color darkScaffoldBackground = Color(0xFF182029);
  static const Color darkSurface = Color(0xFF242E3D);
  static const Color darkCardBackground = Color(0xFF253140);
  static const Color darkElevatedSurface = Color(0xFF2C3E50); // Flat Charcoal
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkBorderLight = Color(0xFF3E4E63);
  static const Color darkInputBackground = Color(0xFF1E2631);
  static const Color darkTextPrimary = Color(0xFFECF0F1); // Cloud White (Contrast > 13:1)
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 (Contrast > 6.8:1)
  static const Color darkTextMuted = Color(0xFF8DA2BA); // Slate 350 (Contrast > 4.6:1, WCAG AA compliant)
  static const Color darkHyperlink = Color(0xFF38BDF8); // Sky Blue (Contrast > 8.4:1 on dark)

  // ── WCAG AA Compliant Button / Status Accents (White Text Contrast >= 4.5:1) ─
  static const Color wcagEmerald = Color(0xFF1E8449); // Deep Emerald (Contrast 4.72:1 with white)
  static const Color wcagCobalt = Color(0xFF2563EB);  // Deep Cobalt (Contrast 4.56:1 with white)
  static const Color wcagCrimson = Color(0xFFC0392B); // Flat Crimson (Contrast 5.12:1 with white)
  static const Color wcagOrange = Color(0xFFB45309);  // Deep Amber/Orange (Contrast 4.65:1 with white)

  // ── Neutral Tokens (light-theme greys, surfaces on filled colours) ───────────
  /// Pure white: card surfaces and text/icons on filled (cobalt/emerald/...) backgrounds.
  static const Color white = Color(0xFFFFFFFF);
  /// Pure black: shadows and scrims only (use `.withOpacity`/alpha).
  static const Color black = Color(0xFF000000);
  /// Secondary text on light surfaces (grey 600, contrast 4.6:1 on white).
  static const Color textSecondary = Color(0xFF757575);
  /// Stronger secondary text on light surfaces (grey 700).
  static const Color textStrong = Color(0xFF616161);
  /// Hints, disabled icons and placeholders on light surfaces (grey 500).
  static const Color textMuted = Color(0xFF9E9E9E);


  // ── Semantic Surface / Border / Text Tokens (additive) ────────────────────
  // Light-theme values; use the `...Of(context)` helpers to get the adaptive
  // (light/dark) value. Feature code should prefer these over raw greys.

  /// Primary surface (cards, dialogs, inputs on light theme).
  static const Color surface = Color(0xFFFFFFFF);
  /// Alternate surface: zebra rows, table headers, subtle panels.
  static const Color surfaceAlt = Color(0xFFF7F9FB);
  /// Hairline border for cards, inputs and dividers.
  static const Color border = Color(0xFFE2E8F0);
  /// Stronger border: hovered inputs, outlined buttons, emphasised separators.
  static const Color borderStrong = Color(0xFFCBD5E1);
  /// Primary text on light surfaces (charcoal).
  static const Color textPrimary = charcoal;
  /// Subdued text for captions on light surfaces (slate 500, contrast 4.8:1).
  static const Color textCaption = Color(0xFF64748B);

  // Severity backgrounds (opaque tints) + foregrounds (WCAG AA on the tint).
  static const Color successBackground = Color(0xFFE8F6EE);
  static const Color warningBackground = Color(0xFFFDF1E4);
  static const Color dangerBackground = Color(0xFFFBEAE8);
  static const Color infoBackground = Color(0xFFE8F3FB);
  static const Color successForeground = wcagEmerald;
  static const Color warningForeground = wcagOrange;
  static const Color dangerForeground = wcagCrimson;
  static const Color infoForeground = wcagCobalt;

  // Dark counterparts of the severity tints.
  static const Color _successBackgroundDark = Color(0xFF16352A);
  static const Color _warningBackgroundDark = Color(0xFF3A2A18);
  static const Color _dangerBackgroundDark = Color(0xFF3B1F20);
  static const Color _infoBackgroundDark = Color(0xFF17304A);

  // ── Radii & Shadows (additive) ────────────────────────────────────────────
  /// Chips, badges, small inner elements.
  static const double radiusSm = 6.0;
  /// Controls: buttons, inputs, menus.
  static const double radiusMd = 8.0;
  /// Containers: cards, panels, dialogs, tables.
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;

  /// Soft two-layer elevation for cards and panels (light).
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A1E293B), blurRadius: 2, offset: Offset(0, 1)),
  ];
  /// Slightly stronger shadow for popovers / floating surfaces.
  static const List<BoxShadow> shadowFloating = [
    BoxShadow(color: Color(0x1F1E293B), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0F1E293B), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Adaptive helpers (light/dark).
  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkCardBackground : surface;
  static Color surfaceAltOf(BuildContext context) =>
      isDark(context) ? darkInputBackground : surfaceAlt;
  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;
  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textCaption;
  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;
  static Color primaryOf(BuildContext context) => cobalt;

  /// Foreground colour of a [AppSeverity].
  static Color severityColor(AppSeverity severity, {bool dark = false}) {
    switch (severity) {
      case AppSeverity.success:
        return dark ? emerald : successForeground;
      case AppSeverity.warning:
        return dark ? orange : warningForeground;
      case AppSeverity.danger:
        return dark ? const Color(0xFFE5655A) : dangerForeground;
      case AppSeverity.info:
        return dark ? cobalt : infoForeground;
    }
  }

  /// Background tint of a [AppSeverity].
  static Color severityBackground(AppSeverity severity, {bool dark = false}) {
    switch (severity) {
      case AppSeverity.success:
        return dark ? _successBackgroundDark : successBackground;
      case AppSeverity.warning:
        return dark ? _warningBackgroundDark : warningBackground;
      case AppSeverity.danger:
        return dark ? _dangerBackgroundDark : dangerBackground;
      case AppSeverity.info:
        return dark ? _infoBackgroundDark : infoBackground;
    }
  }

  static Color severityForegroundOf(BuildContext context, AppSeverity s) =>
      severityColor(s, dark: isDark(context));
  static Color severityBackgroundOf(BuildContext context, AppSeverity s) =>
      severityBackground(s, dark: isDark(context));

  /// Standard floating, rounded, severity-coloured SnackBar.
  static SnackBar snackBar(
    BuildContext context,
    String message, {
    AppSeverity severity = AppSeverity.info,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final icon = switch (severity) {
      AppSeverity.success => Icons.check_circle_outline,
      AppSeverity.warning => Icons.warning_amber_rounded,
      AppSeverity.danger => Icons.error_outline,
      AppSeverity.info => Icons.info_outline,
    };
    final bg = switch (severity) {
      AppSeverity.success => wcagEmerald,
      AppSeverity.warning => wcagOrange,
      AppSeverity.danger => wcagCrimson,
      AppSeverity.info => charcoal,
    };
    return SnackBar(
      backgroundColor: bg,
      duration: duration,
      action: action,
      content: Row(
        children: [
          Icon(icon, color: white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: white))),
        ],
      ),
    );
  }

  // ── Context-Aware Theme & Decoration Helpers ──────────────────────────────

  /// Detect whether the current context is rendering in Dark Mode.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Standard card/panel decoration — adaptive to light/dark brightness.
  static BoxDecoration cardDecorationOf(BuildContext context) =>
      isDark(context) ? darkCardDecoration : cardDecoration;

  /// Lighter decoration for toolbar containers — adaptive.
  static BoxDecoration toolbarDecorationOf(BuildContext context) =>
      isDark(context) ? darkToolbarDecoration : toolbarDecoration;

  /// Decoration for action pill containers — adaptive.
  static BoxDecoration pillDecorationOf(BuildContext context) =>
      isDark(context) ? darkPillDecoration : pillDecoration;

  // ── Shared BoxDecorations (Legacy & Static) ───────────────────────────────

  /// Standard card/panel decoration — used in toolbars and form sections (Light).
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: border),
        boxShadow: shadowSoft,
      );

  /// Dark card/panel decoration.
  static BoxDecoration get darkCardDecoration => BoxDecoration(
        color: darkCardBackground,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: darkBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );

  /// Lighter decoration for toolbar containers (Light).
  static BoxDecoration get toolbarDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E293B), blurRadius: 6, offset: Offset(0, 2)),
        ],
      );

  /// Dark toolbar decoration.
  static BoxDecoration get darkToolbarDecoration => BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: darkBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x29000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      );

  /// Decoration for action pill containers (Light).
  static BoxDecoration get pillDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Color(0x081E293B), blurRadius: 3, offset: Offset(0, 1)),
        ],
      );

  /// Dark pill decoration.
  static BoxDecoration get darkPillDecoration => BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: darkBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x20000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      );

  /// Glyph fallback for text styles that set their own `fontFamily` (for
  /// example 'monospace'): Arabic then still renders with a Windows font.
  static const List<String> fontFamilyFallback = ['Segoe UI', 'Tahoma'];

  /// Type scale. Letter spacing is 0 everywhere: positive tracking (the M3
  /// default for body/label styles) breaks Arabic letter joining. Line heights
  /// leave room for Arabic diacritics/ascenders.
  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle s(double size, FontWeight w, double h, {Color? c}) => TextStyle(
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: 0,
          color: c ?? primary,
        );
    return TextTheme(
      displayLarge: s(40, FontWeight.w700, 1.2),
      displayMedium: s(34, FontWeight.w700, 1.2),
      displaySmall: s(28, FontWeight.w700, 1.25),
      headlineLarge: s(26, FontWeight.w700, 1.3),
      headlineMedium: s(22, FontWeight.w700, 1.3),
      headlineSmall: s(19, FontWeight.w700, 1.35),
      titleLarge: s(17, FontWeight.w700, 1.4),
      titleMedium: s(15, FontWeight.w600, 1.45),
      titleSmall: s(13.5, FontWeight.w600, 1.45),
      bodyLarge: s(14.5, FontWeight.w400, 1.5),
      bodyMedium: s(13.5, FontWeight.w400, 1.5),
      bodySmall: s(12, FontWeight.w400, 1.5, c: secondary),
      labelLarge: s(13, FontWeight.w600, 1.45),
      labelMedium: s(12, FontWeight.w600, 1.45),
      labelSmall: s(11, FontWeight.w500, 1.45, c: secondary),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /// Dark Theme (الوضع الليلي المكتبي عالي التباين)
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final Color scaffold = dark ? darkScaffoldBackground : cloudWhite;
    final Color surfaceColor = dark ? darkSurface : surface;
    final Color cardColor = dark ? darkCardBackground : surface;
    final Color borderColor = dark ? darkBorder : border;
    final Color borderStrongColor = dark ? darkBorderLight : borderStrong;
    final Color onSurface = dark ? darkTextPrimary : charcoal;
    final Color secondaryText = dark ? darkTextSecondary : textCaption;
    final Color mutedText = dark ? darkTextMuted : textMuted;
    final Color inputFill = dark ? darkInputBackground : surfaceAlt;
    final Color headingRow = dark ? darkInputBackground : const Color(0xFFF1F5F9);

    final colorScheme = (dark
            ? const ColorScheme.dark(
                primary: cobalt,
                secondary: emerald,
                error: crimson,
                surface: darkSurface,
                onSurface: darkTextPrimary,
                surfaceContainerHighest: darkElevatedSurface,
                outline: darkBorder,
              )
            : const ColorScheme.light(
                primary: cobalt,
                secondary: emerald,
                error: crimson,
                surface: surface,
                onSurface: charcoal,
                surfaceContainerHighest: Color(0xFFF1F4F8),
                outline: border,
              ))
        .copyWith(outlineVariant: borderColor);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: c, width: w),
        );

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: cobalt,
      scaffoldBackgroundColor: scaffold,
      cardColor: cardColor,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: fontFamilyFallback,
      colorScheme: colorScheme,
      textTheme: _textTheme(onSurface, secondaryText),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF141A22) : charcoal,
        foregroundColor: cloudWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: cloudWhite,
          letterSpacing: 0,
        ),
      ),

      // Global Scrollbar Theme across all pages
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.hovered) ? 9.0 : 7.0),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) return cobalt;
          if (states.contains(WidgetState.hovered)) {
            return cobalt.withValues(alpha: 0.85);
          }
          return dark ? const Color(0xFF475569) : borderStrong;
        }),
        trackColor: WidgetStateProperty.all(
            dark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9)),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x1A1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: borderColor),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? darkElevatedSurface : surface,
        elevation: 12,
        shadowColor: const Color(0x331E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: dark ? BorderSide(color: borderColor) : BorderSide.none,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.4,
          letterSpacing: 0,
          color: onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          letterSpacing: 0,
          color: onSurface,
        ),
      ),

      // Input Decoration Theme (Forms & Inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        isDense: true,
        contentPadding:
            const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        labelStyle: TextStyle(
            color: secondaryText, fontSize: 13.5, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(
            color: cobalt, fontSize: 13.5, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: mutedText, fontSize: 13),
        helperStyle: TextStyle(color: secondaryText, fontSize: 11.5),
        errorStyle: const TextStyle(
            color: crimson, fontSize: 11.5, fontWeight: FontWeight.w500),
        prefixIconColor: secondaryText,
        suffixIconColor: secondaryText,
        border: inputBorder(borderColor),
        enabledBorder: inputBorder(borderColor),
        disabledBorder: inputBorder(borderColor.withValues(alpha: 0.6)),
        focusedBorder: inputBorder(cobalt, 1.8),
        errorBorder: inputBorder(crimson, 1.4),
        focusedErrorBorder: inputBorder(crimson, 1.8),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cobalt,
          foregroundColor: white,
          elevation: 1,
          shadowColor: const Color(0x401E293B),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: buttonShape,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cobalt,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: buttonShape,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: borderStrongColor),
          shape: buttonShape,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? darkHyperlink : wcagCobalt,
          shape: buttonShape,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: 0),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: buttonShape),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),

      // DataTable Theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(headingRow),
        headingRowHeight: 44,
        headingTextStyle: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0,
        ),
        dataTextStyle: TextStyle(color: onSurface, fontSize: 13, letterSpacing: 0),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cobaltLight;
          if (states.contains(WidgetState.hovered)) {
            return dark ? const Color(0x33FFFFFF) : const Color(0xFFF1F5F9);
          }
          return null;
        }),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),

      // Chips / badges
      chipTheme: ChipThemeData(
        backgroundColor: dark ? darkInputBackground : const Color(0xFFF1F5F9),
        selectedColor: cobaltMedium,
        disabledColor: borderColor,
        side: BorderSide(color: borderColor),
        labelStyle: TextStyle(
            color: onSurface, fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(
            color: cobalt, fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
      ),

      // Tabs
      tabBarTheme: TabBarThemeData(
        labelColor: dark ? darkHyperlink : wcagCobalt,
        unselectedLabelColor: secondaryText,
        labelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 0),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500, letterSpacing: 0),
        indicatorColor: cobalt,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: borderColor,
        overlayColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.hovered) ? cobaltLight : null),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F172A) : charcoal,
          borderRadius: BorderRadius.circular(radiusMd),
          boxShadow: shadowFloating,
        ),
        textStyle: const TextStyle(
            color: white, fontSize: 12, height: 1.4, letterSpacing: 0),
      ),

      // SnackBar: floating, rounded
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? darkElevatedSurface : charcoal,
        contentTextStyle: const TextStyle(
            color: white, fontSize: 13.5, height: 1.4, letterSpacing: 0),
        actionTextColor: dark ? darkHyperlink : const Color(0xFF8FD0FF),
        elevation: 6,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),

      // Menus / popups
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x331E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: borderColor),
        ),
        textStyle: TextStyle(color: onSurface, fontSize: 13.5, letterSpacing: 0),
      ),

      // Selection controls
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: borderStrongColor, width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: cobalt),
      listTileTheme: ListTileThemeData(
        iconColor: secondaryText,
        textColor: onSurface,
      ),
    );
  }
}

/// Semantic severity used by badges, banners and snackbars.
enum AppSeverity { success, warning, danger, info }
