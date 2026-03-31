import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  Widget build(BuildContext context) {
    final effectiveDecoration =
        (decoration ?? const InputDecoration()).copyWith(
      labelText: decoration?.labelText ?? label,
      hintText: decoration?.hintText ?? hintText,
      suffixIcon: decoration?.suffixIcon ?? suffixIcon,
    );

    return TextFormField(
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
    );
  }
}
