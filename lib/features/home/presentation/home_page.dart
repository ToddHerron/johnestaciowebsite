import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:john_estacio_website/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const mobileMax = 768.0;
          const tabletMax = 1200.0; // >= 1200 considered desktop

          final isMobile = width <= mobileMax;
          final isTablet = width > mobileMax && width < tabletMax;

          if (isMobile) {
            return _buildMobileLayout(context);
          } else {
            return _buildLargeLayout(context, isTablet: isTablet);
          }
        },
      ),
    );
  }

  // Layout for Mobile phones
  Widget _buildMobileLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height,
      width: size.width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep main body text at the top, add extra top padding per request
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 175), // Extra top padding above the main body title
                  _buildMobileBodyText(),
                ],
              ),
            ),
          ),
          // Photo pinned flush to bottom
          SizedBox(
            height: size.height * 0.45,
            width: size.width,
            child: Image.asset(
              'assets/images/john_without_background.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),
        ],
      ),
    );
  }

  // Layout for Tablets and Desktops
  Widget _buildLargeLayout(BuildContext context, {required bool isTablet}) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Previous width factor was 0.27 (after 60% reduction). Adjust per request:
    // - Desktop: 25% bigger -> 0.27 * 1.25 = 0.3375
    // - Tablet:  50% bigger -> 0.27 * 1.50 = 0.405
    const baseFactor = 0.27;
    final imageWidthFactor = isTablet ? (baseFactor * 1.50) : (baseFactor * 1.25);

    return Stack(
      children: [
        // Left content column
        Positioned(
          left: 0,
          right: screenWidth * 0.4, // keep content in left ~60%
          top: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopHeaderText(),
              ],
            ),
          ),
        ),
        // Image on bottom-right
        Positioned(
          bottom: 0,
          right: 0,
          width: screenWidth * imageWidthFactor,
          child: Image.asset(
            'assets/images/john_without_background.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  // Desktop/tablet header (two-line lockup)
  Widget _buildDesktopHeaderText() {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'JOHN ESTACIO\n',
            style: GoogleFonts.manrope(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: 'COMPOSER',
            style: GoogleFonts.manrope(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightGray,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }


  // Mobile main body text
  Widget _buildMobileBodyText() {
    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'JOHN ESTACIO\n',
            style: GoogleFonts.manrope(
              fontSize: 48, // Adjust font size for mobile body
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: 'COMPOSER',
            style: GoogleFonts.manrope(
              fontSize: 48, // Adjust font size for mobile body
              fontWeight: FontWeight.bold,
              color: AppTheme.lightGray,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }


}
