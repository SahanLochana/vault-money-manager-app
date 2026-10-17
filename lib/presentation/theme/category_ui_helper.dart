import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';

class CategoryUIHelper {
  /// Stable color derived strictly from category ID (palette index = id % palette length).
  /// Never depends on category name.
  static Color getColor(Category? category) {
    if (category == null || category.id == null) {
      return AppColors.textMuted;
    }
    return getColorForId(category.id);
  }

  static Color getColorForId(int? categoryId) {
    if (categoryId == null) return AppColors.textMuted;
    final palette = AppColors.categoryPalette;
    final index = categoryId.abs() % palette.length;
    return palette[index];
  }

  static IconData getIcon(Category? category) {
    return Icons.category_rounded;
  }
}
