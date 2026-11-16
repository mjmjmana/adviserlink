import 'package:flutter/material.dart';

/// Design Tokens - Single source of truth for colors, spacing, typography, radius, shadows
/// Synced from design-tokens.json
class DesignTokens {
  // Colors
  static const Color brandPrimary = Color(0xFFB45BC4);
  static const Color brandPrimaryHover = Color(0xFFC174CF);
  static const Color brandPrimaryLight = Color(0xFFD8C4E8);
  static const Color brandPrimaryDark = Color(0xFF3F0F52);

  // Semantic Dark
  static const Color darkSurface = Color(0xFF130E16);
  static const Color darkSurfaceElevated = Color(0xFF211827);
  static const Color darkSurfaceHover = Color(0xFF302236);
  static const Color darkText = Color(0xFFFAFAFA);
  static const Color darkTextMuted = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF49374F);
  static const Color darkInput = Color(0xFF211827);
  static const Color darkRing = Color(0xFFB45BC4);

  // Semantic Light
  static const Color lightSurface = Color(0xFFFEFCFF);
  static const Color lightSurfaceElevated = Color(0xFFF8F3FA);
  static const Color lightSurfaceHover = Color(0xFFF1EAF5);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextMuted = Color(0xFF52525B);
  static const Color lightBorder = Color(0xFFE4D9EA);
  static const Color lightInput = Color(0xFFF7F1F9);
  static const Color lightRing = Color(0xFF8D348E);

  // Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF14532D);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF78350F);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1E3A5F);

  // Role Colors
  static const Color roleStudent = Color(0xFF3B82F6);
  static const Color roleStudentLight = Color(0xFFDBEAFE);
  static const Color roleStudentDark = Color(0xFF1E3A5F);

  static const Color roleAdviser = Color(0xFF8B5CF6);
  static const Color roleAdviserLight = Color(0xFFEDE9FE);
  static const Color roleAdviserDark = Color(0xFF3C1F6E);

  static const Color roleAdmin = Color(0xFFEF4444);
  static const Color roleAdminLight = Color(0xFFFEE2E2);
  static const Color roleAdminDark = Color(0xFF7F1D1D);

  // Tile Colors - for KPI variety using brand palette
  // Light mode backgrounds
  static const Color tileOrangeLight = Color(0xFFF7E8FA);
  static const Color tileAmberLight = Color(0xFFFEF3C7);
  static const Color tileCoralLight = Color(0xFFFFEDD5);
  static const Color tilePeachLight = Color(0xFFFFF7ED);
  static const Color tileBlueLight = Color(0xFFDBEAFE);
  static const Color tilePurpleLight = Color(0xFFEDE9FE);
  static const Color tileGreenLight = Color(0xFFDCFCE7);
  static const Color tileRoseLight = Color(0xFFFFE4E6);

  // Dark mode backgrounds (with opacity)
  static const Color tileOrangeDark = Color(0x1EB45BC4);
  static const Color tileAmberDark = Color(0x1EF59E0B);
  static const Color tileCoralDark = Color(0x1EF97316);
  static const Color tilePeachDark = Color(0x1EFDBA74);
  static const Color tileBlueDark = Color(0x1E3B82F6);
  static const Color tilePurpleDark = Color(0x1E8B5CF6);
  static const Color tileGreenDark = Color(0x1E16A34A);
  static const Color tileRoseDark = Color(0x1EF43F5E);

  // Tile border colors
  static const Color tileOrangeBorder = Color(0xFFB45BC4);
  static const Color tileAmberBorder = Color(0xFFF59E0B);
  static const Color tileCoralBorder = Color(0xFFF97316);
  static const Color tilePeachBorder = Color(0xFFFDBA74);
  static const Color tileBlueBorder = Color(0xFF3B82F6);
  static const Color tilePurpleBorder = Color(0xFF8B5CF6);
  static const Color tileGreenBorder = Color(0xFF16A34A);
  static const Color tileRoseBorder = Color(0xFFF43F5E);

  // Spacing
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;

  // Radius
  static const double radiusNone = 0;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radius2xl = 20;
  static const double radius3xl = 24;
  static const double radius4xl = 28;
  static const double radiusFull = 9999;

  // Typography
  static const String fontFamilySans = 'Inter';
  static const String fontFamilyMono = 'JetBrains Mono';

  static const TextStyle textXs = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle textSm = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle textBase = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle textLg = TextStyle(
      fontSize: 18,
      height: 28 / 18,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle textXl = TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle text2xl = TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle text3xl = TextStyle(
      fontSize: 30,
      height: 36 / 30,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle text4xl = TextStyle(
      fontSize: 36,
      height: 40 / 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);
  static const TextStyle text5xl = TextStyle(
      fontSize: 48,
      height: 52 / 48,
      fontWeight: FontWeight.w400,
      letterSpacing: 0);

  // Font Weights
  static const FontWeight weightNormal = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtrabold = FontWeight.w800;

  // Shadows
  static List<BoxShadow> shadowNone = [];
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -1)
  ];
  static List<BoxShadow> shadowLg = [
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 10),
        blurRadius: 15,
        spreadRadius: -3)
  ];
  static List<BoxShadow> shadowCard = [
    BoxShadow(
        color: Color(0x26000000),
        offset: Offset(0, 2),
        blurRadius: 8,
        spreadRadius: -2),
    BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 1),
  ];
  static List<BoxShadow> shadowGlow = [
    BoxShadow(
        color: Color(0x66B45BC4),
        offset: Offset(0, 0),
        blurRadius: 20,
        spreadRadius: -5)
  ];

  // New shadows for bento design
  static List<BoxShadow> shadowBento = [
    BoxShadow(
        color: Color(0x40000000),
        offset: Offset(0, 20),
        blurRadius: 50,
        spreadRadius: -10),
    BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 1),
    BoxShadow(
        color: Color(0x26B45BC4),
        offset: Offset(0, 0),
        blurRadius: 60,
        spreadRadius: -20),
  ];

  static List<BoxShadow> shadowCardGlass = [
    BoxShadow(
        color: Color(0x26000000),
        offset: Offset(0, 4),
        blurRadius: 20,
        spreadRadius: -4),
    BoxShadow(
        color: Color(0x14FFFFFF),
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 1),
  ];

  static List<BoxShadow> shadowTileGlow = [
    BoxShadow(
        color: Color(0x4DB45BC4),
        offset: Offset(0, 0),
        blurRadius: 30,
        spreadRadius: -10),
  ];

  // Transitions
  static const Duration transitionFast = Duration(milliseconds: 150);
  static const Duration transitionNormal = Duration(milliseconds: 200);
  static const Duration transitionSlow = Duration(milliseconds: 300);

  // Z-Index
  static const int zBase = 0;
  static const int zDropdown = 100;
  static const int zSticky = 200;
  static const int zFixed = 300;
  static const int zModalBackdrop = 400;
  static const int zModal = 500;
  static const int zPopover = 600;
  static const int zTooltip = 700;
  static const int zToast = 800;

  /// Get color for current brightness
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;
  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceElevated
          : lightSurfaceElevated;
  static Color surfaceHover(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceHover
          : lightSurfaceHover;
  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : lightText;
  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : lightTextMuted;
  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorder
          : lightBorder;
  static Color input(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInput : lightInput;
  static Color ring(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkRing : lightRing;

  /// Tile background colors for current brightness
  static Color tileBg(BuildContext context, String tone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case 'orange':
        return isDark ? tileOrangeDark : tileOrangeLight;
      case 'amber':
        return isDark ? tileAmberDark : tileAmberLight;
      case 'coral':
        return isDark ? tileCoralDark : tileCoralLight;
      case 'peach':
        return isDark ? tilePeachDark : tilePeachLight;
      case 'blue':
        return isDark ? tileBlueDark : tileBlueLight;
      case 'purple':
        return isDark ? tilePurpleDark : tilePurpleLight;
      case 'green':
        return isDark ? tileGreenDark : tileGreenLight;
      case 'rose':
        return isDark ? tileRoseDark : tileRoseLight;
      default:
        return isDark ? tileOrangeDark : tileOrangeLight;
    }
  }

  static Color tileBorder(String tone) {
    switch (tone) {
      case 'orange':
        return tileOrangeBorder;
      case 'amber':
        return tileAmberBorder;
      case 'coral':
        return tileCoralBorder;
      case 'peach':
        return tilePeachBorder;
      case 'blue':
        return tileBlueBorder;
      case 'purple':
        return tilePurpleBorder;
      case 'green':
        return tileGreenBorder;
      case 'rose':
        return tileRoseBorder;
      default:
        return tileOrangeBorder;
    }
  }

  static Color tileIconColor(String tone) {
    return tileBorder(tone);
  }

  /// Status colors with light/dark variants
  static Color successColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? success : successDark;
  static Color successBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? successDark
          : successLight;

  static Color warningColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? warning : warningDark;
  static Color warningBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? warningDark
          : warningLight;

  static Color errorColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? error : errorDark;
  static Color errorBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? errorDark : errorLight;

  static Color infoColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? info : infoDark;
  static Color infoBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? infoDark : infoLight;

  /// Role colors
  static Color roleColor(BuildContext context, String role) {
    switch (role) {
      case 'student':
        return roleStudent;
      case 'adviser':
        return roleAdviser;
      case 'admin':
        return roleAdmin;
      default:
        return brandPrimary;
    }
  }

  static Color roleBg(BuildContext context, String role) {
    switch (role) {
      case 'student':
        return Theme.of(context).brightness == Brightness.dark
            ? roleStudentDark
            : roleStudentLight;
      case 'adviser':
        return Theme.of(context).brightness == Brightness.dark
            ? roleAdviserDark
            : roleAdviserLight;
      case 'admin':
        return Theme.of(context).brightness == Brightness.dark
            ? roleAdminDark
            : roleAdminLight;
      default:
        return brandPrimaryLight;
    }
  }

  /// Spacing helpers
  static EdgeInsets paddingAll(double value) => EdgeInsets.all(value);
  static EdgeInsets paddingSymmetric(
          {double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  static EdgeInsets paddingOnly(
          {double left = 0,
          double top = 0,
          double right = 0,
          double bottom = 0}) =>
      EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);

  /// Radius helpers
  static BorderRadius radius(double value) => BorderRadius.circular(value);
  static BorderRadius radiusSmOnly() => BorderRadius.circular(radiusSm);
  static BorderRadius radiusMdOnly() => BorderRadius.circular(radiusMd);
  static BorderRadius radiusLgOnly() => BorderRadius.circular(radiusLg);
  static BorderRadius radiusXlOnly() => BorderRadius.circular(radiusXl);
  static BorderRadius radius2xlOnly() => BorderRadius.circular(radius2xl);
  static BorderRadius radius3xlOnly() => BorderRadius.circular(radius3xl);
  static BorderRadius radius4xlOnly() => BorderRadius.circular(radius4xl);
  static BorderRadius radiusFullOnly() => BorderRadius.circular(radiusFull);
}

/// Extension for easy access in widgets
extension DesignTokensContext on BuildContext {
  Color get surface => DesignTokens.surface(this);
  Color get surfaceElevated => DesignTokens.surfaceElevated(this);
  Color get surfaceHover => DesignTokens.surfaceHover(this);
  Color get muted =>
      DesignTokens.surfaceHover(this); // Alias for web compatibility
  Color get textColor => DesignTokens.text(this);
  Color get textMuted => DesignTokens.textMuted(this);
  Color get borderColor => DesignTokens.border(this);
  Color get inputColor => DesignTokens.input(this);
  Color get ringColor => DesignTokens.ring(this);
  Color get brandPrimary => DesignTokens.brandPrimary;

  Color successColor() => DesignTokens.successColor(this);
  Color successBg() => DesignTokens.successBg(this);
  Color warningColor() => DesignTokens.warningColor(this);
  Color warningBg() => DesignTokens.warningBg(this);
  Color errorColor() => DesignTokens.errorColor(this);
  Color errorBg() => DesignTokens.errorBg(this);
  Color infoColor() => DesignTokens.infoColor(this);
  Color infoBg() => DesignTokens.infoBg(this);

  Color roleColor(String role) => DesignTokens.roleColor(this, role);
  Color roleBg(String role) => DesignTokens.roleBg(this, role);

  Color tileBg(String tone) => DesignTokens.tileBg(this, tone);
  Color tileBorder(String tone) => DesignTokens.tileBorder(tone);
  Color tileIconColor(String tone) => DesignTokens.tileIconColor(tone);

  double get space1 => DesignTokens.space1;
  double get space2 => DesignTokens.space2;
  double get space3 => DesignTokens.space3;
  double get space4 => DesignTokens.space4;
  double get space5 => DesignTokens.space5;
  double get space6 => DesignTokens.space6;
  double get space8 => DesignTokens.space8;

  double get radiusSm => DesignTokens.radiusSm;
  double get radiusMd => DesignTokens.radiusMd;
  double get radiusLg => DesignTokens.radiusLg;
  double get radiusXl => DesignTokens.radiusXl;
  double get radius2xl => DesignTokens.radius2xl;
  double get radius3xl => DesignTokens.radius3xl;
  double get radius4xl => DesignTokens.radius4xl;

  TextStyle get textXs => DesignTokens.textXs;
  TextStyle get textSm => DesignTokens.textSm;
  TextStyle get textBase => DesignTokens.textBase;
  TextStyle get textLg => DesignTokens.textLg;
  TextStyle get textXl => DesignTokens.textXl;
  TextStyle get text2xl => DesignTokens.text2xl;
  TextStyle get text3xl => DesignTokens.text3xl;
  TextStyle get text4xl => DesignTokens.text4xl;
  TextStyle get text5xl => DesignTokens.text5xl;

  List<BoxShadow> get shadowSm => DesignTokens.shadowSm;
  List<BoxShadow> get shadowMd => DesignTokens.shadowMd;
  List<BoxShadow> get shadowLg => DesignTokens.shadowLg;
  List<BoxShadow> get shadowCard => DesignTokens.shadowCard;
  List<BoxShadow> get shadowGlow => DesignTokens.shadowGlow;
  List<BoxShadow> get shadowBento => DesignTokens.shadowBento;
  List<BoxShadow> get shadowCardGlass => DesignTokens.shadowCardGlass;
  List<BoxShadow> get shadowTileGlow => DesignTokens.shadowTileGlow;
}
