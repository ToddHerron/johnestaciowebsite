import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/quill_viewer.dart';
import 'package:john_estacio_website/theme.dart';

class RichTextViewerDialog extends StatelessWidget {
  final Map<String, dynamic> deltaJson;
  final String title;
  const RichTextViewerDialog(
      {super.key, required this.deltaJson, required this.title});

  @override
  Widget build(BuildContext context) {
    // This theme widget will override the default text styles for all children,
    // making the text white without needing to pass parameters to the QuillViewer.
    final darkTheme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppTheme.white,
            displayColor: AppTheme.white,
          ),
    );

    return AlertDialog(
      backgroundColor: AppTheme.darkGray, // Set the background to dark gray
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.white), // Ensure title is visible
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Theme(
          data: darkTheme,
          child: QuillViewer(
            deltaJson: deltaJson,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ],
    );
  }
}