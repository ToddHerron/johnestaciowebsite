import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:john_estacio_website/core/widgets/quill_editor_configs.dart';
import 'package:john_estacio_website/theme.dart';

/// Unified rich text editor for the app using flutter_quill.
///
/// Visual spec:
/// - Dialog background: handled by callers (white)
/// - Editor container background: white
/// - Editing area (document surface): black
/// - Toolbar controls: dark grey on white
/// - Dropdowns/textfields in toolbar: white background, dark grey text
/// - Fonts limited to Manrope (headings) and Nunito Sans (body)
/// - Color palette limited to black, dark grey, primary orange, light grey, white
class AppRichTextEditor extends StatelessWidget {
  final QuillController controller;
  final double? height;
  final EdgeInsetsGeometry editorPadding;
  final bool expands;

  const AppRichTextEditor({
    super.key,
    required this.controller,
    this.height,
    this.editorPadding = const EdgeInsets.all(12),
    this.expands = false,
  });

  @override
  Widget build(BuildContext context) {
    // The editable document surface is black; text styles ensure legibility
    final editorTheme = Theme.of(context).copyWith(
      // Style horizontal rules inside the editor
      dividerColor: AppTheme.primaryOrange,
      dividerTheme: const DividerThemeData(
        color: AppTheme.primaryOrange,
        thickness: 2,
        space: 16,
      ),
    );

    final editor = Theme(
      data: editorTheme,
      child: Container(
        color: AppTheme.black,
        child: QuillEditor.basic(
          controller: controller,
          config: QuillEditorConfig(
            customStyles: QuillEditorConfigs.customStyles,
            padding: editorPadding,
            expands: expands,
            embedBuilders: FlutterQuillEmbeds.editorBuilders(),
          ),
        ),
      ),
    );

    // Local light theme to make toolbar inputs use white backgrounds and dark text
    final toolbarTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppTheme.primaryOrange,
        secondary: AppTheme.darkGray,
        surface: AppTheme.white,
        onPrimary: AppTheme.black,
        onSecondary: AppTheme.darkGray,
        onSurface: AppTheme.darkGray,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.white,
        labelStyle: TextStyle(color: AppTheme.darkGray),
        hintStyle: TextStyle(color: AppTheme.darkGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: AppTheme.darkGray),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(AppTheme.white),
        ),
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppTheme.darkGray,
            displayColor: AppTheme.darkGray,
          ),
    );

    final toolbar = Theme(
      data: toolbarTheme,
      child: IconTheme(
        data: const IconThemeData(color: AppTheme.darkGray),
        child: QuillSimpleToolbar(
          controller: controller,
          config: QuillSimpleToolbarConfig(
            color: AppTheme.white, // Toolbar background
            // Wrap controls instead of horizontal scroll
            multiRowsDisplay: true,

            // Show only the requested controls
            showUndo: true,
            showRedo: true,

            // Typography
            showFontFamily: false,
            showFontSize: true,
            showHeaderStyle: true, // Normal / H1 / H2 / H3

            // Inline styles
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: false, // removed
            showSubscript: true,
            showSuperscript: true,

            // Block styles
            showQuote: false, // removed
            showIndent: true, // includes indent and outdent

            // Links
            showLink: true,

            // Hide everything else explicitly
            showClearFormat: false,
            showInlineCode: false,
            showListNumbers: false,
            showListBullets: false,
            showListCheck: false,
            showCodeBlock: false,
            showAlignmentButtons: false,
            showSearchButton: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showDirection: false,
            showClipboardCut: false,
            showClipboardCopy: false,
            showClipboardPaste: false,
            showDividers: false,
            // No embed buttons
            embedButtons: const [],
          ),
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        const SizedBox(height: 8),
        if (height != null)
          SizedBox(height: height, child: editor)
        else
          Expanded(child: editor),
      ],
    );

    return Container(
      color: AppTheme.white,
      child: content,
    );
  }
}
