import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum AvatarSize { xs, sm, md, lg, xl, xxl }
enum AvatarShape { circle, rounded }

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final String? initials;
  final AvatarSize size;
  final AvatarShape shape;
  final String? status; // online, offline, busy, away
  final bool showStatus;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.initials,
    this.size = AvatarSize.md,
    this.shape = AvatarShape.circle,
    this.status,
    this.showStatus = false,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  static double _getSize(AvatarSize s) {
    switch (s) {
      case AvatarSize.xs: return 24;
      case AvatarSize.sm: return 32;
      case AvatarSize.md: return 40;
      case AvatarSize.lg: return 48;
      case AvatarSize.xl: return 64;
      case AvatarSize.xxl: return 96;
    }
  }

  static double _getFontSize(AvatarSize s) {
    switch (s) {
      case AvatarSize.xs: return 10;
      case AvatarSize.sm: return 12;
      case AvatarSize.md: return 16;
      case AvatarSize.lg: return 18;
      case AvatarSize.xl: return 24;
      case AvatarSize.xxl: return 36;
    }
  }

  static double _getStatusSize(AvatarSize s) {
    switch (s) {
      case AvatarSize.xs: return 6;
      case AvatarSize.sm: return 8;
      case AvatarSize.md: return 10;
      case AvatarSize.lg: return 12;
      case AvatarSize.xl: return 16;
      case AvatarSize.xxl: return 20;
    }
  }

  String _getInitials() {
    if (initials != null && initials!.isNotEmpty) return initials!.toUpperCase();
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _getBgColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    // Generate consistent color from name
    final hash = (name ?? initials ?? '').codeUnits.fold(0, (a, b) => a + b);
    final colors = [
      const Color(0xFFEF4444), // red
      const Color(0xFFF59E0B), // amber
      const Color(0xFF16A34A), // green
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // violet
      const Color(0xFFEC4899), // pink
      const Color(0xFF06B6D4), // cyan
      const Color(0xFF84CC16), // lime
    ];
    return colors[hash % colors.length];
  }

  Color _getTextColor(BuildContext context) {
    return textColor ?? Colors.white;
  }

  Color _getStatusColor(BuildContext context) {
    switch (status?.toLowerCase()) {
      case 'online': return context.successColor();
      case 'busy': return context.errorColor();
      case 'away': return context.warningColor();
      case 'offline': return context.textMuted;
      default: return context.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sz = _getSize(size);
    final fontSize = _getFontSize(size);
    final statusSize = _getStatusSize(size);
    final bgColor = _getBgColor(context);
    final fgColor = _getTextColor(context);
    final isCircle = shape == AvatarShape.circle;

    Widget avatar = Container(
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(context.radius2xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor.withValues(alpha: isDark ? 0.85 : 0.75),
            bgColor.withValues(alpha: isDark ? 0.65 : 0.55),
          ],
        ),
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: isCircle ? BorderRadius.circular(sz / 2) : BorderRadius.circular(context.radius2xl),
              child: Image.network(imageUrl!, width: sz, height: sz, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallback(context, fontSize, fgColor)),
            )
          : _buildFallback(context, fontSize, fgColor),
    );

    if (showStatus && status != null && status!.isNotEmpty) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: statusSize,
              height: statusSize,
              decoration: BoxDecoration(
                color: _getStatusColor(context),
                shape: BoxShape.circle,
                border: Border.all(color: context.surface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        shape: isCircle ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radius2xl)),
        child: InkWell(
          onTap: onTap,
          borderRadius: isCircle ? BorderRadius.circular(sz / 2) : BorderRadius.circular(context.radius2xl),
          splashColor: context.brandPrimary.withValues(alpha: 0.1),
          highlightColor: context.brandPrimary.withValues(alpha: 0.05),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  Widget _buildFallback(BuildContext context, double fontSize, Color fgColor) {
    return Center(
      child: Text(
        _getInitials(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fgColor, letterSpacing: 0.1),
      ),
    );
  }
}

class AvatarGroup extends StatelessWidget {
  final List<Widget> avatars;
  final int maxVisible;
  final double overlap;
  final AvatarSize size;

  const AvatarGroup({
    super.key,
    required this.avatars,
    this.maxVisible = 5,
    this.overlap = 8,
    this.size = AvatarSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sz = AppAvatar._getSize(size);
    final visible = avatars.take(maxVisible).toList();
    final remaining = avatars.length - maxVisible;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.asMap().entries.map((entry) {
          final index = entry.key;
          final avatar = entry.value;
          return Transform.translate(
            offset: Offset(-index * overlap, 0),
            child: SizedBox(width: sz - index * overlap, child: avatar),
          );
        }),
        if (remaining > 0)
          Transform.translate(
            offset: Offset(-visible.length * overlap, 0),
            child: Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaceHover,
                border: Border.all(color: context.borderColor, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.surfaceHover.withValues(alpha: isDark ? 0.6 : 0.8),
                    context.surfaceHover.withValues(alpha: isDark ? 0.4 : 0.6),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text('+$remaining', style: TextStyle(fontSize: AppAvatar._getFontSize(size) - 2, fontWeight: FontWeight.w700, color: context.textMuted)),
            ),
          ),
      ],
    );
  }
}