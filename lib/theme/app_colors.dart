import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();
  static const Color primary = Color.fromRGBO(182, 172, 196, 1.0);
  static const Color secondary = Color.fromRGBO(234, 210, 154, 1.0);
  static const Color burntOrange = Color.fromRGBO(199, 116, 64, 1.0);
  static const Color pluto = Color.fromRGBO(190, 219, 217, 1.0);
  static const Color fontColor = Color.fromRGBO(17, 17, 17, 1.0);
  static const Color backgroundColor = Color.fromRGBO(252, 251, 251, 1.0);
  static const Color NavigationBarBackground = Color.fromRGBO(
    215,
    183,
    183,
    1.0,
  );
}

class AppTypography {
  AppTypography._();
  static final TextStyle title = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle splashScreen = GoogleFonts.bricolageGrotesque(
    fontSize: 48,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  static final TextStyle nav = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}
