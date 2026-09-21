import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_text_styles.dart';

/// Standardized text field with label, validation, and specialized variants.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixText,
    this.prefix,
    this.prefixIcon,
    this.suffix,
    this.suffixIcon,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    this.initialValue,
    this.enabled = true,
    this.maxLength,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final String? prefixText;
  final Widget? prefix;
  final Widget? prefixIcon;
  final Widget? suffix;
  final Widget? suffixIcon;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final String? initialValue;
  final bool enabled;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: key,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      textInputAction: textInputAction,
      focusNode: focusNode,
      enabled: enabled,
      maxLength: maxLength,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefix: prefix,
        prefixIcon: prefixIcon,
        suffix: suffix,
        suffixIcon: suffixIcon,
        counterText: '', // hide built-in counter
      ),
    );
  }

  // ─── Specialized Factories ───────────────────

  /// Currency amount field: numeric keyboard, ₹ prefix, decimal support.
  factory AppTextField.currency({
    Key? key,
    String? label,
    String? hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    TextInputAction? textInputAction,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      label: label ?? 'Amount',
      hint: hint ?? '0.00',
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      prefixText: '₹ ',
    );
  }

  /// Phone number field: numeric keyboard, 10-digit length cap.
  factory AppTextField.phone({
    Key? key,
    String? label,
    TextEditingController? controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    TextInputAction? textInputAction,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      label: label ?? 'Mobile Number',
      hint: '10-digit mobile',
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      maxLength: 10,
    );
  }

  /// Multi-line notes/memo field.
  factory AppTextField.memo({
    Key? key,
    String? label,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      key: key,
      label: label ?? 'Memo (optional)',
      controller: controller,
      onChanged: onChanged,
      maxLines: 3,
      minLines: 2,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }
}
