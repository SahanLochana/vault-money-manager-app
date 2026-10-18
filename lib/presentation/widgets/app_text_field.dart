import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool autofocus;
  final TextInputType keyboardType;
  final int? maxLines;
  final String? prefixText;
  final TextStyle? prefixStyle;
  final Color accentColor;
  final double borderRadius;
  final Color fillColor;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;
  final ValueChanged<String>? onChanged;
  final bool hasBorder;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.prefixText,
    this.prefixStyle,
    this.accentColor = AppColors.primary,
    this.borderRadius = 12.0,
    this.fillColor = AppColors.surfaceLight,
    this.textStyle,
    this.hintStyle,
    this.contentPadding,
    this.onChanged,
    this.hasBorder = true,
    this.errorText,
    this.inputFormatters,
    this.maxLength,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderSide = hasBorder
        ? const BorderSide(color: AppColors.surfaceBorder)
        : BorderSide.none;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: textStyle ??
          const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle ??
            const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
        prefixText: prefixText,
        prefixStyle: prefixStyle ??
            TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
        errorText: errorText,
        errorMaxLines: 2,
        counterText: "",
        errorStyle: const TextStyle(
          color: AppColors.expense,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: effectiveBorderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: effectiveBorderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(
            color: accentColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(
            color: AppColors.expense,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(
            color: AppColors.expense,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
