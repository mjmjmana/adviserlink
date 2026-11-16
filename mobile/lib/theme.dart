import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design_tokens.dart';

/// Theme mode enum
enum AppThemeMode { system, light, dark }

/// Loads saved theme mode from SharedPreferences
Future<AppThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt('theme_mode') ?? AppThemeMode.dark.index;
  return AppThemeMode.values[index];
}

/// Saves theme mode to SharedPreferences
Future<void> saveThemeMode(AppThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('theme_mode', mode.index);
}

/// Builds dark theme using DesignTokens
ThemeData buildDark() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DesignTokens.brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: DesignTokens.brandPrimary,
      onPrimary: Colors.white,
      surface: DesignTokens.darkSurface,
      onSurface: DesignTokens.darkText,
      surfaceContainerHighest: DesignTokens.darkSurfaceElevated,
      outline: DesignTokens.darkBorder,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: DesignTokens.darkSurface,
    textTheme: base.textTheme.apply(
        bodyColor: DesignTokens.darkText, displayColor: DesignTokens.darkText),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DesignTokens.darkSurfaceElevated,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
          color: DesignTokens.darkText,
          fontSize: 12,
          fontWeight: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : DesignTokens.darkTextMuted,
        ),
      ),
      height: 72,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DesignTokens.darkSurfaceElevated,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.darkBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.darkBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.brandPrimary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.error, width: 2)),
      contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space4, vertical: DesignTokens.space3),
      labelStyle: TextStyle(color: DesignTokens.darkTextMuted),
      hintStyle: TextStyle(color: DesignTokens.darkTextMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DesignTokens.brandPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl)),
        padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.space6, vertical: DesignTokens.space4),
        textStyle: TextStyle(fontWeight: FontWeight.w700),
        minimumSize: const Size(44, 44),
      ),
    ),
    cardTheme: CardThemeData(
      color: DesignTokens.darkSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        side: BorderSide(color: DesignTokens.darkBorder.withOpacity(0.3)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme:
        DividerThemeData(color: DesignTokens.darkBorder, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: DesignTokens.darkSurfaceHover,
      disabledColor: DesignTokens.darkSurfaceHover,
      selectedColor: DesignTokens.brandPrimary.withOpacity(0.2),
      secondarySelectedColor: DesignTokens.brandPrimary.withOpacity(0.3),
      padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
      labelStyle: TextStyle(
          color: DesignTokens.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 12),
      secondaryLabelStyle: TextStyle(
          color: DesignTokens.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          side: BorderSide(color: DesignTokens.darkBorder)),
      side: BorderSide(color: DesignTokens.darkBorder),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return DesignTokens.brandPrimary;
          return DesignTokens.darkSurfaceHover;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return DesignTokens.darkText;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide.none;
          return BorderSide(color: DesignTokens.darkBorder);
        }),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl))),
      ),
    ),
  );
}

/// Builds light theme using DesignTokens
ThemeData buildLight() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DesignTokens.brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: DesignTokens.brandPrimary,
      onPrimary: Colors.white,
      surface: DesignTokens.lightSurface,
      onSurface: DesignTokens.lightText,
      surfaceContainerHighest: DesignTokens.lightSurfaceElevated,
      outline: DesignTokens.lightBorder,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: DesignTokens.lightSurface,
    textTheme: base.textTheme.apply(
        bodyColor: DesignTokens.lightText,
        displayColor: DesignTokens.lightText),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DesignTokens.lightSurfaceElevated,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
          color: DesignTokens.lightText,
          fontSize: 12,
          fontWeight: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : DesignTokens.lightTextMuted,
        ),
      ),
      height: 72,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DesignTokens.lightSurfaceElevated,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.lightBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.lightBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.brandPrimary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: DesignTokens.error, width: 2)),
      contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space4, vertical: DesignTokens.space3),
      labelStyle: TextStyle(color: DesignTokens.lightTextMuted),
      hintStyle: TextStyle(color: DesignTokens.lightTextMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DesignTokens.brandPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl)),
        padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.space6, vertical: DesignTokens.space4),
        textStyle: TextStyle(fontWeight: FontWeight.w700),
        minimumSize: const Size(44, 44),
      ),
    ),
    cardTheme: CardThemeData(
      color: DesignTokens.lightSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        side: BorderSide(color: DesignTokens.lightBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme:
        DividerThemeData(color: DesignTokens.lightBorder, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: DesignTokens.lightSurfaceHover,
      disabledColor: DesignTokens.lightSurfaceHover,
      selectedColor: DesignTokens.brandPrimary.withOpacity(0.15),
      secondarySelectedColor: DesignTokens.brandPrimary.withOpacity(0.2),
      padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.space3, vertical: DesignTokens.space1),
      labelStyle: TextStyle(
          color: DesignTokens.lightText,
          fontWeight: FontWeight.w600,
          fontSize: 12),
      secondaryLabelStyle: TextStyle(
          color: DesignTokens.lightText,
          fontWeight: FontWeight.w600,
          fontSize: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          side: BorderSide(color: DesignTokens.lightBorder)),
      side: BorderSide(color: DesignTokens.lightBorder),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return DesignTokens.brandPrimary;
          return DesignTokens.lightSurfaceHover;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return DesignTokens.lightText;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide.none;
          return BorderSide(color: DesignTokens.lightBorder);
        }),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl))),
      ),
    ),
  );
}

/// Page background for bento design - wraps the entire app content
class BentoBackground extends StatelessWidget {
  final Widget child;
  const BentoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const RadialGradient(
                center: Alignment(1.0, -1.0),
                radius: 1.3,
                colors: [Color(0x55E40093), Color(0xFF260332)],
                stops: [0.0, 0.75],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF2E5F8),
                  Color(0xFFFBF7FE),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
      ),
      child: child,
    );
  }
}

/// Floating bento container - the main app container with rounded corners and shadow
class BentoContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const BentoContainer({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: padding ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isDark
                ? DesignTokens.darkSurfaceElevated
                : DesignTokens.lightSurface,
            borderRadius: BorderRadius.circular(DesignTokens.radius4xl),
            boxShadow: DesignTokens.shadowBento,
            border: Border.all(
              color: isDark
                  ? DesignTokens.darkBorder.withOpacity(0.3)
                  : DesignTokens.lightBorder.withOpacity(0.5),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

/// Glass card - glassy surface with backdrop blur, thin border, 24px radius
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool hover;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.hover = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? DesignTokens.darkSurfaceElevated.withOpacity(0.6)
            : DesignTokens.lightSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        border: Border.all(
          color: isDark
              ? DesignTokens.darkBorder.withOpacity(0.3)
              : DesignTokens.lightBorder.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: DesignTokens.shadowCardGlass,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
          splashColor: DesignTokens.brandPrimary.withOpacity(0.1),
          highlightColor: DesignTokens.brandPrimary.withOpacity(0.05),
          child: card,
        ),
      );
    }

    if (hover) {
      return AnimatedContainer(
        duration: DesignTokens.transitionNormal,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isDark
              ? DesignTokens.darkSurfaceElevated.withOpacity(0.6)
              : DesignTokens.lightSurface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(DesignTokens.radius3xl),
          border: Border.all(
            color: isDark
                ? DesignTokens.darkBorder.withOpacity(0.3)
                : DesignTokens.lightBorder.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: DesignTokens.shadowMd,
        ),
        padding: padding,
        child: child,
      );
    }

    return card;
  }
}

/// KPI Stat Tile - tinted gradient fill, icon circle, large number, caption with delta
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final String? delta;
  final IconData icon;
  final String tone; // orange, amber, coral, peach, blue, purple, green, rose
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.delta,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = context.tileBg(tone);
    final borderColor = context.tileBorder(tone);
    final iconColor = context.tileIconColor(tone);

    final tile = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radius4xl),
        border: Border.all(
            color: borderColor.withOpacity(isDark ? 0.3 : 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              if (onTap != null)
                IconButton(
                  icon: Icon(Icons.open_in_new,
                      size: 18, color: context.textMuted),
                  onPressed: onTap,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: context.text4xl.copyWith(
              fontWeight: DesignTokens.weightExtrabold,
              color: context.textColor,
              height: 1.1,
            ),
          ),
          if (caption != null || delta != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (delta != null) ...[
                  Text(
                    delta!,
                    style: context.textSm.copyWith(
                      fontWeight: DesignTokens.weightBold,
                      color: delta!.startsWith('+') || delta!.startsWith('▲')
                          ? DesignTokens.success
                          : delta!.startsWith('-') || delta!.startsWith('▼')
                              ? DesignTokens.error
                              : context.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (caption != null)
                  Flexible(
                    child: Text(
                      caption!,
                      style: context.textSm.copyWith(color: context.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textXs.copyWith(
              fontWeight: DesignTokens.weightSemibold,
              color: context.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radius4xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radius4xl),
          splashColor: borderColor.withOpacity(0.1),
          highlightColor: borderColor.withOpacity(0.05),
          child: tile,
        ),
      );
    }

    return tile;
  }
}

/// Circular icon button - 44px touch target
class IconButton2 extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? tooltip;
  final bool isSelected;

  const IconButton2({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark
            ? DesignTokens.darkSurfaceHover
            : DesignTokens.lightSurfaceHover);
    final fg = foregroundColor ??
        (isDark ? DesignTokens.darkText : DesignTokens.lightText);

    final btn = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isSelected ? DesignTokens.brandPrimary : bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : (isDark ? DesignTokens.darkBorder : DesignTokens.lightBorder),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          splashColor: DesignTokens.brandPrimary.withOpacity(0.1),
          highlightColor: DesignTokens.brandPrimary.withOpacity(0.05),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : fg,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Status pill - fully rounded, soft tinted background, optional leading dot
class StatusPill extends StatelessWidget {
  final String label;
  final String
      tone; // success, warning, error, info, student, adviser, admin, primary
  final bool showDot;
  final IconData? leadingIcon;

  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.showDot = false,
    this.leadingIcon,
  });

  Color _getColor(BuildContext context) {
    switch (tone) {
      case 'success':
        return DesignTokens.success;
      case 'warning':
        return DesignTokens.warning;
      case 'error':
        return DesignTokens.error;
      case 'info':
        return DesignTokens.info;
      case 'student':
        return DesignTokens.roleStudent;
      case 'adviser':
        return DesignTokens.roleAdviser;
      case 'admin':
        return DesignTokens.roleAdmin;
      case 'primary':
      default:
        return DesignTokens.brandPrimary;
    }
  }

  Color _getBgColor(BuildContext context, Color fg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return fg.withOpacity(isDark ? 0.15 : 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = _getColor(context);
    final bgColor = _getBgColor(context, fgColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        border: Border.all(color: fgColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                  color: fgColor, borderRadius: BorderRadius.circular(3)),
            ),
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 12, color: fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fgColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar with round thumb and percentage ticks
class ProgressBarWithTicks extends StatelessWidget {
  final double value; // 0-100
  final int segments; // number of tick marks
  final String? label;
  final String? valueText;
  final Color? color;
  final double height;

  const ProgressBarWithTicks({
    super.key,
    required this.value,
    this.segments = 10,
    this.label,
    this.valueText,
    this.color,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = color ?? DesignTokens.brandPrimary;
    final trackColor =
        isDark ? DesignTokens.darkSurfaceHover : DesignTokens.lightSurfaceHover;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || valueText != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(label!,
                    style: context.textSm.copyWith(
                        fontWeight: DesignTokens.weightSemibold,
                        color: context.textColor)),
              if (valueText != null)
                Text(valueText!,
                    style: context.textSm.copyWith(
                        fontWeight: DesignTokens.weightBold, color: barColor)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            // Track
            Container(
              height: height,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Progress fill
            FractionallySizedBox(
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor, barColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
            // Thumb
            Positioned(
              left: (value / 100).clamp(0.0, 1.0),
              top: (height - 20) / 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: barColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (segments > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(segments + 1, (i) {
              final pct = (i / segments * 100).round();
              return Text(
                '$pct%',
                style: context.textXs.copyWith(
                  color: pct <= value ? barColor : context.textMuted,
                  fontWeight: pct <= value
                      ? DesignTokens.weightSemibold
                      : DesignTokens.weightNormal,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Info row - round icon, tiny muted label, medium value, circular edit button
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback? onEdit;
  final String? editTooltip;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.onEdit,
    this.editTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = iconColor ?? context.brandPrimary;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          child: Center(child: Icon(icon, size: 18, color: bgColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: context.textXs.copyWith(
                      color: context.textMuted,
                      fontWeight: DesignTokens.weightMedium)),
              Text(value,
                  style: context.textBase.copyWith(
                      fontWeight: DesignTokens.weightSemibold,
                      color: context.textColor)),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton2(
            icon: Icons.edit,
            onPressed: onEdit,
            tooltip: editTooltip ?? 'Edit',
            backgroundColor: isDark
                ? DesignTokens.darkSurfaceHover
                : DesignTokens.lightSurfaceHover,
            foregroundColor: context.textMuted,
          ),
      ],
    );
  }
}

/// Person chip - avatar, name, subtitle, stat pill
class PersonChip extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? statLabel;
  final String? statTone;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const PersonChip({
    super.key,
    required this.name,
    required this.subtitle,
    this.statLabel,
    this.statTone,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? DesignTokens.darkSurfaceElevated.withOpacity(0.5)
            : DesignTokens.lightSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        border: Border.all(
          color: isDark
              ? DesignTokens.darkBorder.withOpacity(0.3)
              : DesignTokens.lightBorder.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: isDark
                ? DesignTokens.darkSurfaceHover
                : DesignTokens.lightSurfaceHover,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.brandPrimary,
                        fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: context.textSm.copyWith(
                      fontWeight: DesignTokens.weightSemibold,
                      color: context.textColor)),
              Text(subtitle,
                  style: context.textXs.copyWith(color: context.textMuted)),
            ],
          ),
          if (statLabel != null && statTone != null) ...[
            const SizedBox(width: 10),
            StatusPill(label: statLabel!, tone: statTone!),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          splashColor: context.brandPrimary.withOpacity(0.1),
          highlightColor: context.brandPrimary.withOpacity(0.05),
          child: chip,
        ),
      );
    }

    return chip;
  }
}

/// Empty state - centered illustration, message, single action
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? DesignTokens.darkSurfaceHover
                    : DesignTokens.lightSurfaceHover,
                borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              ),
              child: Icon(icon,
                  size: 40, color: context.textMuted.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: context.textXl.copyWith(
                    fontWeight: DesignTokens.weightBold,
                    color: context.textColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(description,
                style: context.textBase.copyWith(color: context.textMuted),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radius2xl)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Profile card - centered avatar, name, subtitle, row of round action buttons
class ProfileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final List<ProfileAction> actions;

  const ProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            backgroundColor: isDark
                ? DesignTokens.darkSurfaceHover
                : DesignTokens.lightSurfaceHover,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.brandPrimary,
                        fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(name,
              style: context.text2xl.copyWith(
                  fontWeight: DesignTokens.weightExtrabold,
                  color: context.textColor)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: context.textBase.copyWith(color: context.textMuted)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: actions
                  .map((a) => IconButton2(
                        icon: a.icon,
                        onPressed: a.onPressed,
                        tooltip: a.tooltip,
                        backgroundColor: isDark
                            ? DesignTokens.darkSurfaceHover
                            : DesignTokens.lightSurfaceHover,
                        foregroundColor: context.textColor,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileAction {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const ProfileAction(
      {required this.icon, required this.onPressed, required this.tooltip});
}

/// Light theme bottom sheet / dialog
class LightSheet extends StatelessWidget {
  final Widget child;
  const LightSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? DesignTokens.darkSurfaceElevated
          : DesignTokens.lightSurfaceElevated,
      textStyle: Theme.of(context).textTheme.bodyMedium,
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(DesignTokens.radius4xl)),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: child,
        ),
      ),
    );
  }
}

/// Glow background for dark theme
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(1.0, -1.0),
          radius: 1.3,
          colors: [
            DesignTokens.brandPrimary.withOpacity(0.20),
            DesignTokens.darkSurface
          ],
          stops: const [0.0, 0.75],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.0, 0.6),
            radius: 1.0,
            colors: [
              DesignTokens.brandPrimary.withOpacity(0.08),
              Colors.transparent
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Shows a snackbar
void snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? DesignTokens.error : DesignTokens.brandPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl)),
      margin: EdgeInsets.all(DesignTokens.space4),
    ));
}

/// Status chip widget (legacy - use StatusPill instead)
class Chip2 extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  const Chip2(this.text, {super.key, this.bg, this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: bg ?? context.surfaceHover,
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull)),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg ?? context.textColor)),
      );
}

Chip2 statusChip(String status) {
  switch (status) {
    case 'approved':
    case 'completed':
      return Chip2(status,
          bg: const Color(0xFFDFF0E2), fg: const Color(0xFF2F6B4F));
    case 'declined':
    case 'cancelled':
      return Chip2(status, bg: const Color(0xFFFBE3DC), fg: DesignTokens.error);
    case 'confirmed':
      return Chip2(status, bg: DesignTokens.brandPrimary, fg: Colors.white);
    default:
      return Chip2(status, bg: const Color(0xFFF3D9A8));
  }
}
