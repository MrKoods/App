import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class XpTitleStyle {
  static TextStyle forTitle(
    String title, {
    Color color = Colors.white,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    switch (title) {
      case 'Beginner':
        return GoogleFonts.poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.1,
        );
      case 'Getting Started':
        return GoogleFonts.nunito(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.2,
        );
      case 'Consistent':
        return GoogleFonts.rajdhani(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.5,
        );
      case 'Focused':
        return GoogleFonts.sora(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.3,
        );
      case 'Locked In':
        return GoogleFonts.orbitron(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.5,
        );
      case 'Disciplined':
        return GoogleFonts.exo2(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.4,
        );
      case 'Momentum':
        return GoogleFonts.audiowide(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.6,
        );
      case 'Elite':
        return GoogleFonts.oxanium(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.7,
        );
      case 'Unstoppable':
        return GoogleFonts.chakraPetch(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.8,
        );
      case 'Legend':
        return GoogleFonts.cinzelDecorative(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        );
      default:
        return TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
    }
  }
}
