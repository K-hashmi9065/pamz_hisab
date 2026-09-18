import 'package:flutter/material.dart';

/// Semantic color tokens — never use raw `Colors.*` in feature code.
/// All colors are referenced from ThemeData extensions or directly via this class.
abstract final class AppColors {
  // --- Brand ---
  static const Color primary = Color(0xFF1A6B4A); // Deep emerald green
  static const Color primaryLight = Color(0xFF2E9A6B);
  static const Color primaryDark = Color(0xFF0D4A33);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // --- Semantic Finance ---
  /// Credit: money owed TO the user / income (always green family)
  static const Color credit = Color(0xFF2E7D32);
  static const Color creditLight = Color(0xFFE8F5E9);
  static const Color creditText = Color(0xFF1B5E20);

  /// Debit: money owed BY the user / expense (always red family)
  static const Color debit = Color(0xFFC62828);
  static const Color debitLight = Color(0xFFFFEBEE);
  static const Color debitText = Color(0xFFB71C1C);

  /// Warning: approaching due date / near budget threshold
  static const Color warning = Color(0xFFF57F17);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color warningText = Color(0xFFE65100);

  // --- Surface & Background ---
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F8);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // --- Text ---
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFB0B7BF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // --- Outline & Divider ---
  static const Color outline = Color(0xFFDDE3EA);
  static const Color divider = Color(0xFFEEF1F5);

  // --- Dark Mode variants ---
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1C1F2A);
  static const Color darkSurfaceVariant = Color(0xFF252836);
  static const Color darkCardBackground = Color(0xFF1C1F2A);
  static const Color darkOutline = Color(0xFF2E3348);
  static const Color darkTextPrimary = Color(0xFFE8EAF0);
  static const Color darkTextSecondary = Color(0xFF9AA3B2);

  // --- Status ---
  static const Color success = Color(0xFF00897B);
  static const Color info = Color(0xFF1976D2);
  static const Color error = Color(0xFFD32F2F);

  // --- Sidebar Nav ---
  static const Color sidebarBackground = Color(0xFF0D1F1A);
  static const Color sidebarSelected = Color(0xFF1A6B4A);
  static const Color sidebarSelectedIndicator = Color(0xFF2E9A6B);
}
