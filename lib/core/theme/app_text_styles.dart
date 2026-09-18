import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';



/// Typography system for PAMZ Hisab.
/// Uses Poppins for headings, NotoSans for body (Devanagari-safe), RobotoMono for amounts.
/// All sizes use `.sp` from flutter_screenutil.
abstract final class AppTextStyles {
  AppTextStyles._();

  // --- Display (Dashboard headline totals) ---
  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 30.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  // --- Headings ---
  static TextStyle get h1 => GoogleFonts.poppins(
        fontSize: 22.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get h2 => GoogleFonts.poppins(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get h3 => GoogleFonts.poppins(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      );

  // --- Body (NotoSans for Devanagari glyph support) ---
  static TextStyle get body => GoogleFonts.notoSans(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => GoogleFonts.notoSans(
        fontSize: 15.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodySmall => GoogleFonts.notoSans(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      );

  // --- Amount (tabular monospace for column alignment) ---
  static TextStyle get amount => GoogleFonts.robotoMono(
        fontSize: 18.sp,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountLarge => GoogleFonts.robotoMono(
        fontSize: 24.sp,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get amountSmall => GoogleFonts.robotoMono(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // --- Caption (timestamps, memo, helper text) ---
  static TextStyle get caption => GoogleFonts.notoSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get captionBold => GoogleFonts.notoSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      );

  // --- Button ---
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  // --- Label ---
  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  // --- Navigation Rail ---
  static TextStyle get navLabel => GoogleFonts.poppins(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
      );

  // --- Helpers: apply color overrides ---
  static TextStyle amountColored(Color color) => amount.copyWith(color: color);
  static TextStyle bodyColored(Color color) => body.copyWith(color: color);
}
