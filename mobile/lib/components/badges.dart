import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum BadgeVariant { defaultBadge, secondary, destructive, success, warning, info, outline, roleStudent, roleAdviser, roleAdmin }
enum BadgeSize { sm, md, lg }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final BadgeSize size;
  final bool dot;
  final IconData? icon;
  final Color? customColor;
  final Color? customBg;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.defaultBadge,
    this.size = BadgeSize.md,
    this.dot = false,
    this.icon,
    this.customColor,
    this.customBg,
    this.onTap,
  });

  static Color _getColor(BuildContext context, BadgeVariant v, {bool bg = false}) {
    if (bg) {
      switch (v) {
        case BadgeVariant.defaultBadge: return context.brandPrimary.withValues(alpha: 0.12);
        case BadgeVariant.secondary: return context.surfaceHover;
        case BadgeVariant.destructive: return context.errorBg();
        case BadgeVariant.success: return context.successBg();
        case BadgeVariant.warning: return context.warningBg();
        case BadgeVariant.info: return context.infoBg();
        case BadgeVariant.outline: return Colors.transparent;
        case BadgeVariant.roleStudent: return context.roleBg('student');
        case BadgeVariant.roleAdviser: return context.roleBg('adviser');
        case BadgeVariant.roleAdmin: return context.roleBg('admin');
      }
    }
    switch (v) {
      case BadgeVariant.defaultBadge: return context.brandPrimary;
      case BadgeVariant.secondary: return context.textMuted;
      case BadgeVariant.destructive: return context.errorColor();
      case BadgeVariant.success: return context.successColor();
      case BadgeVariant.warning: return context.warningColor();
      case BadgeVariant.info: return context.infoColor();
      case BadgeVariant.outline: return context.textColor;
      case BadgeVariant.roleStudent: return context.roleColor('student');
      case BadgeVariant.roleAdviser: return context.roleColor('adviser');
      case BadgeVariant.roleAdmin: return context.roleColor('admin');
    }
  }

  static BoxBorder? _getBorder(BuildContext context, BadgeVariant v) {
    if (v == BadgeVariant.outline) return Border.all(color: context.borderColor, width: 1.5);
    final c = _getColor(context, v);
    return Border.all(color: c.withValues(alpha: 0.25), width: 1);
  }

  static EdgeInsets _getPadding(BadgeSize s, BuildContext context) {
    switch (s) {
      case BadgeSize.sm: return EdgeInsets.symmetric(horizontal: context.space3, vertical: context.space1);
      case BadgeSize.md: return EdgeInsets.symmetric(horizontal: context.space3, vertical: context.space1);
      case BadgeSize.lg: return EdgeInsets.symmetric(horizontal: context.space4, vertical: context.space2);
    }
  }

  static double _getFontSize(BadgeSize s, BuildContext context) {
    switch (s) {
      case BadgeSize.sm: return 11;
      case BadgeSize.md: return 12;
      case BadgeSize.lg: return 14;
    }
  }

  static double _getGap(BadgeSize s, BuildContext context) {
    switch (s) {
      case BadgeSize.sm: return context.space1;
      case BadgeSize.md: return context.space2;
      case BadgeSize.lg: return context.space3;
    }
  }

  static double _getDotSize(BadgeSize s) {
    switch (s) {
      case BadgeSize.sm: return 5;
      case BadgeSize.md: return 6;
      case BadgeSize.lg: return 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? _getColor(context, variant);
    final bg = customBg ?? _getColor(context, variant, bg: true);
    final border = _getBorder(context, variant);
    final padding = _getPadding(size, context);
    final fontSize = _getFontSize(size, context);
    final gap = _getGap(size, context);
    final dotSize = _getDotSize(size);

    Widget badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            SizedBox(width: gap),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: badge,
        ),
      );
    }

    return badge;
  }
}

/// Status-specific badge with predefined variants
class StatusBadge extends StatelessWidget {
  final String status;
  final BadgeSize size;
  final bool dot;

  const StatusBadge({super.key, required this.status, this.size = BadgeSize.md, this.dot = true});

  static BadgeVariant _variantFor(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return BadgeVariant.warning;
      case 'approved': return BadgeVariant.success;
      case 'declined': return BadgeVariant.destructive;
      case 'completed': return BadgeVariant.success;
      case 'cancelled': return BadgeVariant.destructive;
      case 'confirmed': return BadgeVariant.info;
      case 'in_progress': return BadgeVariant.info;
      case 'for_review': return BadgeVariant.warning;
      case 'done': return BadgeVariant.success;
      case 'to_do': return BadgeVariant.secondary;
      default: return BadgeVariant.defaultBadge;
    }
  }

  static String _labelFor(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'approved': return 'Approved';
      case 'declined': return 'Declined';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'confirmed': return 'Confirmed';
      case 'in_progress': return 'In Progress';
      case 'for_review': return 'For Review';
      case 'done': return 'Done';
      case 'to_do': return 'To Do';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: _labelFor(status), variant: _variantFor(status), size: size, dot: dot);
  }
}

/// Role badge
class RoleBadge extends StatelessWidget {
  final String role;
  final BadgeSize size;
  final bool dot;

  const RoleBadge({super.key, required this.role, this.size = BadgeSize.md, this.dot = true});

  static BadgeVariant _variantFor(String r) {
    switch (r.toLowerCase()) {
      case 'student': return BadgeVariant.roleStudent;
      case 'adviser': return BadgeVariant.roleAdviser;
      case 'admin': return BadgeVariant.roleAdmin;
      default: return BadgeVariant.defaultBadge;
    }
  }

  static String _labelFor(String r) {
    switch (r.toLowerCase()) {
      case 'student': return 'Student';
      case 'adviser': return 'Adviser';
      case 'admin': return 'Admin';
      default: return r;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: _labelFor(role), variant: _variantFor(role), size: size, dot: dot);
  }
}

/// Count badge for notifications
class CountBadge extends StatelessWidget {
  final int count;
  final int max;
  final BadgeVariant variant;
  final BadgeSize size;

  const CountBadge({super.key, required this.count, this.max = 99, this.variant = BadgeVariant.defaultBadge, this.size = BadgeSize.sm});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final display = count > max ? '$max+' : '$count';
    return AppBadge(label: display, variant: variant, size: size, dot: false);
  }
}