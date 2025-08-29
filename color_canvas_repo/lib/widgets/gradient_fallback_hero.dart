import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'network_aware_image.dart';

class GradientFallbackHero extends StatefulWidget {
  final String? heroImageUrl;
  final String fallbackSvgDataUri;
  final double height;
  final BorderRadius? borderRadius;
  final Duration crossFadeDuration;
  final bool enableParallax;
  final bool wifiOnlyPref;

  const GradientFallbackHero({
    super.key,
    required this.heroImageUrl,
    required this.fallbackSvgDataUri,
    this.height = 280,
    this.borderRadius,
    this.crossFadeDuration = const Duration(milliseconds: 400),
    this.enableParallax = true,
    this.wifiOnlyPref = false,
  });

  @override
  State<GradientFallbackHero> createState() => _GradientFallbackHeroState();
}

class _GradientFallbackHeroState extends State<GradientFallbackHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _heroImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.crossFadeDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GradientFallbackHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if hero image URL changed and trigger fade if needed
    if (oldWidget.heroImageUrl != widget.heroImageUrl) {
      final hasNewHeroImage = widget.heroImageUrl?.isNotEmpty == true;
      if (hasNewHeroImage && !_heroImageLoaded) {
        _fadeController.forward();
        setState(() {
          _heroImageLoaded = true;
        });
      } else if (!hasNewHeroImage && _heroImageLoaded) {
        _fadeController.reverse();
        setState(() {
          _heroImageLoaded = false;
        });
      }
    }
  }

  Widget _buildFallbackHero() {
    // Parse SVG from data URI
    String svgContent = '';
    try {
      final dataUri = widget.fallbackSvgDataUri;
      if (dataUri.startsWith('data:image/svg+xml;base64,')) {
        final base64Data = dataUri.substring('data:image/svg+xml;base64,'.length);
        svgContent = utf8.decode(base64Decode(base64Data));
      }
    } catch (e) {
      // Fallback to a simple gradient if SVG parsing fails
    }

    if (svgContent.isNotEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: SvgPicture.string(
          svgContent,
          fit: BoxFit.cover,
        ),
      );
    }

    // Simple gradient fallback if SVG parsing fails
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.palette,
          color: Colors.white.withOpacity(0.6),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (widget.heroImageUrl?.isEmpty != false) {
      return _buildFallbackHero();
    }

    return NetworkAwareImage(
      imageUrl: widget.heroImageUrl!,
      wifiOnlyPref: widget.wifiOnlyPref,
      width: double.infinity,
      height: widget.height,
      fit: BoxFit.cover,
      borderRadius: widget.borderRadius,
      isHeavyAsset: true, // Hero images are considered heavy assets
      placeholder: _buildFallbackHero(),
      errorWidget: _buildFallbackHero(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHeroImage = widget.heroImageUrl?.isNotEmpty == true;
    
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            // Always show fallback first (instant render)
            _buildFallbackHero(),
            
            // Fade in the hero image when available
            if (hasHeroImage)
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildHeroImage(),
              ),
          ],
        ),
      ),
    );
  }
}