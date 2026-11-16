import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// Primary button - main actions
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? iconLeft;
  final IconData? iconRight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool elevated;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.iconLeft,
    this.iconRight,
    this.backgroundColor,
    this.foregroundColor,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.brandPrimary;
    final fg = foregroundColor ?? Colors.white;
    final disabled = onPressed == null || loading;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: AnimatedContainer(
        duration: DesignTokens.transitionFast,
        curve: Curves.easeOut,
        transform: !disabled && elevated ? Matrix4.translationValues(0, -1, 0) : Matrix4.identity(),
        decoration: !disabled && elevated
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(context.radius2xl),
                boxShadow: [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              )
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(context.radius2xl),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(context.radius2xl),
            splashColor: fg.withValues(alpha: 0.15),
            highlightColor: fg.withValues(alpha: 0.08),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.space6, vertical: context.space4),
              decoration: BoxDecoration(
                color: disabled ? bg.withValues(alpha: 0.5) : bg,
                borderRadius: BorderRadius.circular(context.radius2xl),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconLeft != null) ...[
                    Icon(iconLeft, size: 18, color: fg),
                    SizedBox(width: context.space2),
                  ],
                  loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(fg),
                          ),
                        )
                      : Text(label, style: context.textBase.copyWith(fontWeight: DesignTokens.weightSemibold, color: fg, letterSpacing: 0.1)),
                  if (iconRight != null && !loading) ...[
                    SizedBox(width: context.space2),
                    Icon(iconRight, size: 18, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button - alternative actions
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? iconLeft;
  final IconData? iconRight;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.iconLeft,
    this.iconRight,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.radius2xl),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(context.radius2xl),
          splashColor: context.brandPrimary.withValues(alpha: 0.1),
          highlightColor: context.brandPrimary.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: DesignTokens.transitionFast,
            decoration: BoxDecoration(
              color: disabled ? Colors.transparent : null,
              borderRadius: BorderRadius.circular(context.radius2xl),
              border: Border.all(
                color: disabled ? context.borderColor.withValues(alpha: 0.5) : context.borderColor,
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: context.space6, vertical: context.space4),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconLeft != null) ...[
                  Icon(iconLeft, size: 18, color: disabled ? context.textMuted : context.textColor),
                  SizedBox(width: context.space2),
                ],
                loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(context.textColor)),
                      )
                    : Text(label, style: context.textBase.copyWith(fontWeight: DesignTokens.weightSemibold, color: disabled ? context.textMuted : context.textColor, letterSpacing: 0.1)),
                if (iconRight != null && !loading) ...[
                  SizedBox(width: context.space2),
                  Icon(iconRight, size: 18, color: disabled ? context.textMuted : context.textColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost button - subtle actions
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final IconData? iconLeft;
  final IconData? iconRight;
  final Color? color;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = false,
    this.iconLeft,
    this.iconRight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? context.brandPrimary;
    final disabled = onPressed == null;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.radius2xl),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(context.radius2xl),
          splashColor: btnColor.withValues(alpha: 0.12),
          highlightColor: btnColor.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: DesignTokens.transitionFast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radius2xl),
            ),
            padding: EdgeInsets.symmetric(horizontal: context.space5, vertical: context.space3),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconLeft != null) ...[
                  Icon(iconLeft, size: 18, color: disabled ? context.textMuted : btnColor),
                  SizedBox(width: context.space2),
                ],
                Text(label, style: context.textBase.copyWith(fontWeight: DesignTokens.weightSemibold, color: disabled ? context.textMuted : btnColor, letterSpacing: 0.1)),
                if (iconRight != null) ...[
                  SizedBox(width: context.space2),
                  Icon(iconRight, size: 18, color: disabled ? context.textMuted : btnColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive button - delete/dangerous actions
class DestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? iconLeft;

  const DestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.iconLeft,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final errorColor = context.errorColor();

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: AnimatedContainer(
        duration: DesignTokens.transitionFast,
        curve: Curves.easeOut,
        transform: !disabled ? Matrix4.translationValues(0, -1, 0) : Matrix4.identity(),
        decoration: !disabled
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(context.radius2xl),
                boxShadow: [
                  BoxShadow(
                    color: errorColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              )
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(context.radius2xl),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(context.radius2xl),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.space6, vertical: context.space4),
              decoration: BoxDecoration(
                color: disabled ? errorColor.withValues(alpha: 0.5) : errorColor,
                borderRadius: BorderRadius.circular(context.radius2xl),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconLeft != null) ...[
                    Icon(iconLeft, size: 18, color: Colors.white),
                    SizedBox(width: context.space2),
                  ],
                  loading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(label, style: context.textBase.copyWith(fontWeight: DesignTokens.weightSemibold, color: Colors.white, letterSpacing: 0.1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Success button - positive actions
class SuccessButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? iconLeft;
  final IconData? iconRight;

  const SuccessButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.iconLeft,
    this.iconRight,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final successColor = context.successColor();

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: AnimatedContainer(
        duration: DesignTokens.transitionFast,
        curve: Curves.easeOut,
        transform: !disabled ? Matrix4.translationValues(0, -1, 0) : Matrix4.identity(),
        decoration: !disabled
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(context.radius2xl),
                boxShadow: [
                  BoxShadow(
                    color: successColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              )
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(context.radius2xl),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(context.radius2xl),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.space6, vertical: context.space4),
              decoration: BoxDecoration(
                color: disabled ? successColor.withValues(alpha: 0.5) : successColor,
                borderRadius: BorderRadius.circular(context.radius2xl),
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconLeft != null) ...[
                    Icon(iconLeft, size: 18, color: Colors.white),
                    SizedBox(width: context.space2),
                  ],
                  loading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(label, style: context.textBase.copyWith(fontWeight: DesignTokens.weightSemibold, color: Colors.white, letterSpacing: 0.1)),
                  if (iconRight != null && !loading) ...[
                    SizedBox(width: context.space2),
                    Icon(iconRight, size: 18, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon button - compact actions
class IconButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final bool selected;

  const IconButtonWidget({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.size = 44,
    this.color,
    this.backgroundColor,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? context.textColor;
    final bgColor = backgroundColor ?? (selected ? context.brandPrimary.withValues(alpha: 0.15) : Colors.transparent);
    final disabled = onPressed == null;

    Widget btn = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(context.radiusXl),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(context.radiusXl),
        splashColor: btnColor.withValues(alpha: 0.1),
        highlightColor: btnColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: DesignTokens.transitionFast,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: disabled ? Colors.transparent : bgColor,
            borderRadius: BorderRadius.circular(context.radiusXl),
            border: selected ? Border.all(color: context.brandPrimary.withValues(alpha: 0.3), width: 1.5) : null,
          ),
          child: Icon(icon, size: 22, color: disabled ? context.textMuted : (selected ? context.brandPrimary : btnColor)),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    return btn;
  }
}