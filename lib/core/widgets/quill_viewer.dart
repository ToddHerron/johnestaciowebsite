import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:john_estacio_website/core/widgets/quill_editor_configs.dart';

class QuillViewer extends StatelessWidget {
  final Map<String, dynamic> deltaJson;

  const QuillViewer({required this.deltaJson, super.key});

  @override
  Widget build(BuildContext context) {
    // Create a Quill controller from the JSON data.
    final controller = QuillController(
      document: Document.fromJson(deltaJson['ops']),
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Render content using QuillEditor with custom styles and in read-only mode.
    return QuillEditor.basic(
      controller: controller,
      config: QuillEditorConfig(
        customStyles: QuillEditorConfigs.customStyles, // Apply custom styles
        expands: false,
        padding: EdgeInsets.zero,
        embedBuilders: FlutterQuillEmbeds.editorBuilders(),
      ),
    );
  }
}