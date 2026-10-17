import 'package:flutter/material.dart';

class AppColors {
  // Background & Surfaces
  static const background = Color(0xFF0F0F14);
  static const surface = Color(0xFF181822);
  static const surfaceLight = Color(0xFF222230);
  static const surfaceBorder = Color(0xFF2C2C3E);

  // Accents & FinTech Palette
  static const primary = Color(0xFF00D09C); // Vibrant Mint / Emerald
  static const primaryDark = Color(0xFF009F75);
  static const secondary = Color(0xFF6C5CE7); // Deep modern violet
  
  // Status & Cash Flow
  static const expense = Color(0xFFFF5252);
  static const income = Color(0xFF00D09C);
  static const warning = Color(0xFFFFB300);

  // Text colors
  static const textPrimary = Color(0xFFF5F6FA);
  static const textSecondary = Color(0xFF9090A6);
  static const textMuted = Color(0xFF63637B);

  // Curated stable category color palette (indexed by category.id % length)
  static const List<Color> categoryPalette = [
    Color(0xFFFF9F43), // Warm amber
    Color(0xFF00D2D3), // Turquoise
    Color(0xFF54A0FF), // Soft blue
    Color(0xFF9B59B6), // Purple
    Color(0xFF10AC84), // Emerald
    Color(0xFFFF6B6B), // Coral
    Color(0xFFFECA57), // Sunflower
    Color(0xFF48DBFB), // Cyan
    Color(0xFF1DD1A1), // Mint
    Color(0xFFFF9FF3), // Pink
    Color(0xFF5F27CD), // Indigo
  ];
}
