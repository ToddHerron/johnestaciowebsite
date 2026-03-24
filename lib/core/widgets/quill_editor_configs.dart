import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:john_estacio_website/theme.dart';

class QuillEditorConfigs {
  
  // Define the list of fonts that will be available in the toolbar.
  static Map<String, String> get fontFamilies => {
        'Manrope': 'Manrope',
        'Nunito Sans': 'Nunito Sans',
      };

  static Map<String, Color> get customColors => {
        'Black': AppTheme.black,
        'Dark Gray': AppTheme.darkGray,
        'Primary Orange': AppTheme.primaryOrange,
        'Light Gray': AppTheme.lightGray,
        'White': AppTheme.white,
      };

  // Define the custom styles for the editor content.
  static DefaultStyles get customStyles {
    return DefaultStyles(
      h1: DefaultTextBlockStyle(
        GoogleFonts.manrope(
          fontSize: 34,
          color: AppTheme.primaryOrange,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      h2: DefaultTextBlockStyle(
        GoogleFonts.manrope(
          fontSize: 24,
          color: AppTheme.lightGray,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      paragraph: DefaultTextBlockStyle(
        GoogleFonts.nunitoSans(
          fontSize: 16,
          color: AppTheme.lightGray,
          height: 1.5,
          fontWeight: FontWeight.normal,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
      // Keep other styles like lists, block quotes, etc., as default
      lists: DefaultListBlockStyle(
         GoogleFonts.nunitoSans(
          fontSize: 16,
          color: AppTheme.lightGray,
          height: 1.5,
          fontWeight: FontWeight.normal,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        null,
        null
      ),
       quote: DefaultTextBlockStyle(
        GoogleFonts.nunitoSans(
          fontSize: 16,
          color: AppTheme.lightGray,
          height: 1.5,
          fontWeight: FontWeight.normal,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
       code: DefaultTextBlockStyle(
        GoogleFonts.nunitoSans(
          fontSize: 16,
          color: AppTheme.lightGray,
          height: 1.5,
          fontWeight: FontWeight.normal,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        const VerticalSpacing(0, 0),
        null,
      ),
    );
  }
}