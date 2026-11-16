import 'package:flutter/material.dart';
import '../design_tokens.dart';

class AppInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? error;
  final String? initialValue;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool invalid;
  final bool enabled;
  final bool readOnly;
  final bool required;
  final int? maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final String? helperText;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.initialValue,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.invalid = false,
    this.enabled = true,
    this.readOnly = false,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.helperText,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _obscureText = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _obscureText = widget.obscureText;
    _focusNode
        .addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null || widget.invalid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !widget.enabled;
    final passwordLabel =
        widget.label?.toLowerCase().contains('confirm') == true
            ? 'confirm password'
            : 'password';

    List<BoxShadow>? boxShadow;

    if (disabled) {
      // No shadow for disabled
    } else if (hasError) {
      // No shadow for error
    } else if (_focused) {
      boxShadow = [
        BoxShadow(
          color: context.brandPrimary.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 0),
          spreadRadius: 0,
        ),
      ];
    } else if (_hovered) {
      // No shadow for hovered
    } else {
      // No shadow for default
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(bottom: context.space2),
            child: Row(
              children: [
                Text(widget.label!,
                    style: context.textSm.copyWith(
                        fontWeight: DesignTokens.weightSemibold,
                        color: context.textColor)),
                if (widget.required)
                  Text(' *',
                      style: context.textSm.copyWith(
                          color: context.errorColor(),
                          fontWeight: DesignTokens.weightBold)),
              ],
            ),
          ),
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: DesignTokens.transitionFast,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radius2xl),
              boxShadow: boxShadow,
            ),
            child: TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              obscureText: _obscureText,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.validator,
              style: context.textBase
                  .copyWith(color: context.textColor, letterSpacing: 0.1),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: context.textBase.copyWith(
                    color: context.textMuted.withValues(alpha: 0.6),
                    letterSpacing: 0.1),
                helperText: widget.helperText,
                helperStyle: context.textSm.copyWith(color: context.textMuted),
                errorText: widget.error,
                errorStyle:
                    context.textSm.copyWith(color: context.errorColor()),
                counterText: '',
                filled: true,
                fillColor: disabled
                    ? context.surfaceElevated
                        .withValues(alpha: isDark ? 0.3 : 0.5)
                    : context.inputColor,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: context.space4, vertical: context.space3),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon,
                        size: 20,
                        color: _focused
                            ? context.brandPrimary
                            : context.textMuted.withValues(alpha: 0.7))
                    : null,
                suffixIcon: widget.suffixIcon != null
                    ? IconButton(
                        tooltip: widget.obscureText
                            ? '${_obscureText ? 'Show' : 'Hide'} $passwordLabel'
                            : null,
                        icon: Icon(
                          _obscureText && widget.obscureText
                              ? Icons.visibility_off
                              : widget.suffixIcon,
                          size: 20,
                          color: _focused
                              ? context.brandPrimary
                              : context.textMuted.withValues(alpha: 0.7),
                        ),
                        onPressed: widget.onSuffixTap ??
                            () => setState(() => _obscureText = !_obscureText),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide:
                      BorderSide(color: context.borderColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide: BorderSide(
                      color: hasError
                          ? context.errorColor()
                          : disabled
                              ? context.borderColor.withValues(alpha: 0.4)
                              : context.borderColor,
                      width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide: BorderSide(
                      color: hasError
                          ? context.errorColor()
                          : context.brandPrimary,
                      width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide:
                      BorderSide(color: context.errorColor(), width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide: BorderSide(color: context.errorColor(), width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.radius2xl),
                  borderSide: BorderSide(
                      color: context.borderColor.withValues(alpha: 0.4),
                      width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppTextarea extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? error;
  final TextEditingController? controller;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? helperText;

  const AppTextarea({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.controller,
    this.minLines = 3,
    this.maxLines = 6,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: context.space2),
            child: Text(label!,
                style: context.textSm.copyWith(
                    fontWeight: DesignTokens.weightSemibold,
                    color: context.textColor)),
          ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          style: context.textBase
              .copyWith(color: context.textColor, letterSpacing: 0.1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.textBase.copyWith(
                color: context.textMuted.withValues(alpha: 0.6),
                letterSpacing: 0.1),
            helperText: helperText,
            helperStyle: context.textSm.copyWith(color: context.textMuted),
            errorText: error,
            errorStyle: context.textSm.copyWith(color: context.errorColor()),
            filled: true,
            fillColor: disabled
                ? context.surfaceElevated.withValues(alpha: isDark ? 0.3 : 0.5)
                : context.inputColor,
            contentPadding: EdgeInsets.all(context.space4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(
                  color: disabled
                      ? context.borderColor.withValues(alpha: 0.4)
                      : context.borderColor,
                  width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.brandPrimary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.errorColor(), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.errorColor(), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(
                  color: context.borderColor.withValues(alpha: 0.4),
                  width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class AppSelect<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? error;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T?>? validator;
  final bool enabled;
  final String? helperText;

  const AppSelect({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.value,
    required this.items,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: context.space2),
            child: Text(label!,
                style: context.textSm.copyWith(
                    fontWeight: DesignTokens.weightSemibold,
                    color: context.textColor)),
          ),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: disabled ? null : onChanged,
          validator: validator,
          style: context.textBase
              .copyWith(color: context.textColor, letterSpacing: 0.1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.textBase.copyWith(
                color: context.textMuted.withValues(alpha: 0.6),
                letterSpacing: 0.1),
            helperText: helperText,
            helperStyle: context.textSm.copyWith(color: context.textMuted),
            errorText: error,
            errorStyle: context.textSm.copyWith(color: context.errorColor()),
            filled: true,
            fillColor: disabled
                ? context.surfaceElevated.withValues(alpha: isDark ? 0.3 : 0.5)
                : context.inputColor,
            contentPadding: EdgeInsets.symmetric(
                horizontal: context.space4, vertical: context.space3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(
                  color: disabled
                      ? context.borderColor.withValues(alpha: 0.4)
                      : context.borderColor,
                  width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.brandPrimary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.errorColor(), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(color: context.errorColor(), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius2xl),
              borderSide: BorderSide(
                  color: context.borderColor.withValues(alpha: 0.4),
                  width: 1.5),
            ),
          ),
          dropdownColor: context.surfaceElevated,
          icon: Icon(Icons.keyboard_arrow_down, color: context.textMuted),
          selectedItemBuilder: (context) =>
              items.map((item) => Text(item.value.toString())).toList(),
        ),
      ],
    );
  }
}
