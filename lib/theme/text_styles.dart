import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized text style helpers using Cinzel (headings) & Spectral (body)
/// via google_fonts, matching the web prototype's serif courtroom look.
class AppText {
  static TextStyle cinzel({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.cinzel(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? 0.5,
  );

  static TextStyle spectral({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    FontStyle? fontStyle,
    double? height,
  }) => GoogleFonts.spectral(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontStyle: fontStyle,
    height: height,
  );
}
