import 'package:flutter/material.dart';

class IframeView extends StatelessWidget {
  final String htmlContent;
  final double height;
  final double? width;

  const IframeView({super.key, required this.htmlContent, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    // Fallback for non-web platforms.
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(20),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Embedded content preview is available on the web version.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}