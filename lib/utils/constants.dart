import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const String ADMIN_EMAIL = 'elfhflflfh1237118@gmail.com';

const Color CORRECT_OPTION_COLOR = Color.fromRGBO(0, 255, 0, 0.2);
const Color INCORRECT_OPTION_COLOR = Color.fromRGBO(255, 0, 0, 0.2);

// Add a function to get the app's text style
TextStyle getAppTextStyle(BuildContext context,
    {double? fontSize, FontWeight? fontWeight}) {
  return GoogleFonts.notoSans(
    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
  );
}
