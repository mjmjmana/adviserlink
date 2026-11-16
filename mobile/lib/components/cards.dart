import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum CardVariant { defaultCard, elevated, outlined, glass, ghost, soft, brand }

enum CardPadding { none, sm, md, lg, xl }

class AppCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final CardPadding padding;
  final bool hover;
  final VoidCallback? onTap;
  final EdgeInsets? customPadding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.defaultCard,
    this.padding = CardPadding.md,
    this.hover = false,
    this.onTap,
    this.customPadding,
    this.borderRadius,
    this.backgroundColor,
    this.shadows,
    this.border,
  });

  static EdgeInsets _getPadding(CardPadding p, BuildContext context) {
    switch (p) {
      case CardPadding.none:
        return EdgeInsets.zero;
      case CardPadding.sm:
        return EdgeInsets.all(context.space3);
      case CardPadding.md:
        return EdgeInsets.all(context.space5);
      case CardPadding.lg:
        return EdgeInsets.all(context.space6);
      case CardPadding.xl:
        return EdgeInsets.all(context.space8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = customPadding ?? _getPadding(padding, context);
    final rad = borderRadius ?? BorderRadius.circular(context.radius2xl);

    Color bgColor;
    List<BoxShadow> boxShadows;
    Border boxBorder;

    switch (variant) {
      case CardVariant.defaultCard:
        bgColor = backgroundColor ?? context.surfaceElevated;
        boxShadows = shadows ?? (hover ? context.shadowMd : context.shadowCard);
        boxBorder = border ?? Border.all(color: context.borderColor, width: 1);
        break;
      case CardVariant.elevated:
        bgColor = backgroundColor ?? context.surfaceElevated;
        boxShadows = shadows ?? context.shadowLg;
        boxBorder = border ?? Border.all(color: context.borderColor.withValues(alpha: 0.5), width: 1);
        break;
      case CardVariant.outlined:
        bgColor = backgroundColor ?? Colors.transparent;
        boxShadows = shadows ?? (hover ? context.shadowSm : []);
        boxBorder = border ?? Border.all(color: context.borderColor, width: 2);
        break;
      case CardVariant.glass:
        bgColor = backgroundColor ?? (isDark
            ? context.surfaceElevated.withValues(alpha: 0.6)
            : context.surface.withValues(alpha: 0.8));
        boxShadows = shadows ?? context.shadowCard;
        boxBorder = border ?? Border.all(
            color: isDark
                ? context.borderColor.withValues(alpha: 0.3)
                : context.borderColor.withValues(alpha: 0.5),
            width: 1);
        break;
      case CardVariant.ghost:
        bgColor = backgroundColor ?? Colors.transparent;
        boxShadows = shadows ?? [];
        boxBorder = border ?? Border.all(color: Colors.transparent, width: 0);
        break;
      case CardVariant.soft:
        bgColor = backgroundColor ?? context.muted.withValues(alpha: isDark ? 0.3 : 0.5);
        boxShadows = shadows ?? (hover ? context.shadowMd : context.shadowCard);
        boxBorder = border ?? Border.all(
            color: context.borderColor.withValues(alpha: 0.4),
            width: 1);
        break;
      case CardVariant.brand:
        bgColor = backgroundColor ?? Colors.transparent;
        boxShadows = shadows ?? (hover ? context.shadowLg : context.shadowCard);
        boxBorder = border ?? Border.all(
            color: context.brandPrimary.withValues(alpha: 0.2),
            width: 1);
        break;
    }

    Widget card = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: rad,
        border: boxBorder,
        boxShadow: boxShadows,
        gradient: variant == CardVariant.brand
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.brandPrimary.withValues(alpha: isDark ? 0.12 : 0.08),
                  context.brandPrimary.withValues(alpha: isDark ? 0.06 : 0.04),
                ],
              )
            : null,
      ),
      padding: pad,
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: rad,
        child: InkWell(
          onTap: onTap,
          borderRadius: rad,
          splashColor: context.brandPrimary.withValues(alpha: 0.1),
          highlightColor: context.brandPrimary.withValues(alpha: 0.05),
          child: card,
        ),
      );
    }

    if (hover) {
      card = AnimatedContainer(
        duration: DesignTokens.transitionNormal,
        curve: Curves.easeOut,
        transform: hover ? Matrix4.translationValues(0, -3, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: rad,
          border: boxBorder,
          boxShadow: hover ? (variant == CardVariant.brand ? context.shadowLg : context.shadowMd) : boxShadows,
          gradient: variant == CardVariant.brand
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.brandPrimary.withValues(alpha: isDark ? 0.15 : 0.1),
                    context.brandPrimary.withValues(alpha: isDark ? 0.08 : 0.06),
                  ],
                )
              : null,
        ),
        padding: pad,
        child: child,
      );
    }

    return card;
  }
}

/// Card header with title and description
class CardHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? action;
  final CrossAxisAlignment crossAxisAlignment;

  const CardHeader({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  Text(title, style: context.textXl.copyWith(fontWeight: DesignTokens.weightBold, color: context.textColor, letterSpacing: -0.3)),
                  if (description != null) ...[
                    SizedBox(height: context.space1),
                    Text(description!, style: context.textSm.copyWith(color: context.textMuted, height: 1.4)),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ],
    );
  }
}

/// Card footer with actions
class CardFooter extends StatelessWidget {
  final List<Widget> actions;
  final MainAxisAlignment alignment;
  final double spacing;

  const CardFooter({
    super.key,
    required this.actions,
    this.alignment = MainAxisAlignment.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: context.space4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: alignment,
        children: actions
            .expand((widget) => [widget, SizedBox(width: spacing)])
            .take(actions.length * 2 - 1)
            .toList(),
      ),
    );
  }
}