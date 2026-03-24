import 'package:flutter/material.dart';

class PublicPageScaffold extends StatelessWidget {
  final Widget child;

  const PublicPageScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    // Show only the provided content on all public pages (no background image).
    return Scaffold(
      backgroundColor: Colors.black,
      body: child,
    );
  }
}