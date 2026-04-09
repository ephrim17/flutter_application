import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

enum AppTextFieldVariant {
  standard,
  search,
}

InputDecoration appTextFieldDecoration(
  BuildContext context, {
  AppTextFieldVariant variant = AppTextFieldVariant.standard,
  String? labelText,
  String? hintText,
  Widget? suffixIcon,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  String? helperText,
  TextStyle? helperStyle,
  EdgeInsetsGeometry? contentPadding,
}) {
  final theme = Theme.of(context);

  if (variant == AppTextFieldVariant.search) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      prefixIconConstraints: prefixIconConstraints,
      helperText: helperText,
      helperStyle: helperStyle,
      contentPadding: contentPadding,
    );
  }

  const borderColor = Color(0xFFE0D6FB);
  final primary = theme.colorScheme.primary;
  const fieldRadius = Radius.circular(28);

  OutlineInputBorder outline(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(fieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: hintText,
    labelText: labelText,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIconConstraints,
    helperText: helperText,
    helperStyle: helperStyle,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
    hintStyle: theme.textTheme.titleMedium?.copyWith(
      color: const Color(0xFF858197),
      fontWeight: FontWeight.w400,
    ),
    labelStyle: theme.textTheme.titleSmall?.copyWith(
      color: primary.withValues(alpha: 0.9),
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: theme.textTheme.titleSmall?.copyWith(
      color: primary,
      fontWeight: FontWeight.w600,
    ),
    enabledBorder: outline(borderColor, 1.25),
    focusedBorder: outline(primary, 1.7),
    errorBorder: outline(theme.colorScheme.error, 1.3),
    focusedErrorBorder: outline(theme.colorScheme.error, 1.6),
    disabledBorder: outline(borderColor.withValues(alpha: 0.72), 1.0),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.suffixIcon,
    this.validator,
    this.onTap,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.onChanged,
    this.textInputAction,
    this.decoration,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.variant = AppTextFieldVariant.standard,
  });

  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final InputDecoration? decoration;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final AppTextFieldVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseDecoration = appTextFieldDecoration(
      context,
      variant: variant,
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
    );

    final effectiveDecoration = baseDecoration.copyWith(
      labelText: decoration?.labelText ?? label,
      hintText: decoration?.hintText ?? hintText,
      suffixIcon: decoration?.suffixIcon ?? suffixIcon,
      prefixIcon: decoration?.prefixIcon,
      prefixIconConstraints: decoration?.prefixIconConstraints,
      helperText: decoration?.helperText,
      helperStyle: decoration?.helperStyle,
      errorText: decoration?.errorText,
      errorStyle: decoration?.errorStyle,
      counterText: decoration?.counterText,
      contentPadding:
          decoration?.contentPadding ?? baseDecoration.contentPadding,
      filled: decoration?.filled ?? baseDecoration.filled,
      fillColor: decoration?.fillColor ?? baseDecoration.fillColor,
      border: decoration?.border ?? baseDecoration.border,
      enabledBorder: decoration?.enabledBorder ?? baseDecoration.enabledBorder,
      focusedBorder: decoration?.focusedBorder ?? baseDecoration.focusedBorder,
      errorBorder: decoration?.errorBorder ?? baseDecoration.errorBorder,
      focusedErrorBorder:
          decoration?.focusedErrorBorder ?? baseDecoration.focusedErrorBorder,
      disabledBorder:
          decoration?.disabledBorder ?? baseDecoration.disabledBorder,
      floatingLabelBehavior: decoration?.floatingLabelBehavior ??
          baseDecoration.floatingLabelBehavior,
      floatingLabelStyle:
          decoration?.floatingLabelStyle ?? baseDecoration.floatingLabelStyle,
      labelStyle: decoration?.labelStyle ?? baseDecoration.labelStyle,
      hintStyle: decoration?.hintStyle ?? baseDecoration.hintStyle,
      isDense: decoration?.isDense ?? baseDecoration.isDense,
    );

    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      textInputAction: textInputAction,
      decoration: effectiveDecoration,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled,
      style: theme.textTheme.titleMedium?.copyWith(
        color: const Color(0xFF23212D),
        fontWeight: FontWeight.w500,
      ),
    );

    if (variant == AppTextFieldVariant.search) {
      return field;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: field,
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.isExpanded = true,
    this.enabled = true,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final bool isExpanded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: carouselBoxDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: DropdownButtonFormField<T>(
          initialValue: initialValue,
          isExpanded: isExpanded,
          decoration: appTextFieldDecoration(
            context,
            labelText: labelText,
            hintText: hintText,
            helperText: helperText,
          ).copyWith(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 22),
          ),
          borderRadius: BorderRadius.circular(cornerRadius),
          dropdownColor: Theme.of(context).cardTheme.color,
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
