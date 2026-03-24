import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:ui_web' as ui; // For platformViewRegistry
import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/shimmer_placeholder.dart';

class IframeView extends StatefulWidget {
  final String htmlContent;
  final double height;
  final double? width;

  const IframeView({super.key, required this.htmlContent, required this.height, this.width});

  @override
  State<IframeView> createState() => _IframeViewState();
}

class _IframeViewState extends State<IframeView> {
  late final String _viewType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _viewType = 'platform-iframe-view-${UniqueKey()}';

    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final element = web.document.createElement('div') as web.HTMLDivElement;
      element.style.width = '100%';
      element.style.height = '100%';

      // Insert provided HTML directly. Ensure the source is trusted.
      element.innerHTML = widget.htmlContent.toJS;

      return element;
    });

    // Increased delay to ensure shimmer is visible and content has time to load.
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The SizedBox provides the necessary constraints for both the placeholder and the iframe.
    return SizedBox(
      height: widget.height,
      width: widget.width, // Pass width without a fallback to allow natural expansion
      child: _isLoading
          ? ShimmerPlaceholder(height: widget.height, width: widget.width)
          : HtmlElementView(viewType: _viewType),
    );
  }
}
