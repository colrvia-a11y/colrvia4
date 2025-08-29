import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/network_utils.dart';

/// A network-aware image widget that respects Wi-Fi only preferences
/// and shows a tap-to-load overlay on cellular when restricted
class NetworkAwareImage extends StatefulWidget {
  final String imageUrl;
  final bool wifiOnlyPref;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? semanticLabel;
  final bool isHeavyAsset; // Images > 500KB should set this to true
  
  const NetworkAwareImage({
    super.key,
    required this.imageUrl,
    required this.wifiOnlyPref,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
    this.isHeavyAsset = false,
  });

  @override
  State<NetworkAwareImage> createState() => _NetworkAwareImageState();
}

class _NetworkAwareImageState extends State<NetworkAwareImage> {
  bool _shouldLoad = false;
  bool _isLoading = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _checkShouldLoad();
    _updateConnectionStatus();
  }

  Future<void> _checkShouldLoad() async {
    if (!widget.isHeavyAsset) {
      // Light images always load
      setState(() => _shouldLoad = true);
      return;
    }

    final shouldLoad = await NetworkGuard.shouldLoadHeavyAsset(
      wifiOnlyPref: widget.wifiOnlyPref,
      assetKey: widget.imageUrl,
    );
    
    if (mounted) {
      setState(() => _shouldLoad = shouldLoad);
    }
  }

  Future<void> _updateConnectionStatus() async {
    final status = await NetworkGuard.getConnectionStatus();
    if (mounted) {
      setState(() => _connectionStatus = status);
    }
  }

  Future<void> _onTapToLoad() async {
    setState(() => _isLoading = true);
    
    // Override the cellular restriction for this asset
    final canLoad = await NetworkGuard.shouldLoadHeavyAsset(
      wifiOnlyPref: widget.wifiOnlyPref,
      assetKey: widget.imageUrl,
      forceLoad: true,
    );
    
    if (mounted) {
      setState(() {
        _shouldLoad = canLoad;
        _isLoading = false;
      });
    }
  }

  Widget _buildTapToLoadOverlay() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _onTapToLoad,
          borderRadius: widget.borderRadius,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to load on cellular',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect to Wi-Fi for auto-loading',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_connectionStatus != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Connected via $_connectionStatus',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldLoad && widget.isHeavyAsset) {
      return _buildTapToLoadOverlay();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => 
          widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: widget.borderRadius,
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      errorWidget: (context, url, error) =>
          widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: widget.borderRadius,
            ),
            child: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}