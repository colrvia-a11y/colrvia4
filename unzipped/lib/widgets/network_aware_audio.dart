import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/network_utils.dart';

/// A network-aware audio widget that respects Wi-Fi only preferences
/// and shows a tap-to-load overlay on cellular when restricted
class NetworkAwareAudio extends StatefulWidget {
  final String audioUrl;
  final bool wifiOnlyPref;
  final Widget Function(BuildContext context, AudioPlayer player, bool canLoad)? builder;
  final VoidCallback? onLoadBlocked;
  
  const NetworkAwareAudio({
    super.key,
    required this.audioUrl,
    required this.wifiOnlyPref,
    this.builder,
    this.onLoadBlocked,
  });

  @override
  State<NetworkAwareAudio> createState() => _NetworkAwareAudioState();
}

class _NetworkAwareAudioState extends State<NetworkAwareAudio> {
  final AudioPlayer _player = AudioPlayer();
  bool _shouldLoad = false;
  bool _isLoading = false;
  bool _hasBeenBlocked = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _checkShouldLoad();
    _updateConnectionStatus();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _checkShouldLoad() async {
    final shouldLoad = await NetworkGuard.shouldLoadHeavyAsset(
      wifiOnlyPref: widget.wifiOnlyPref,
      assetKey: widget.audioUrl,
    );
    
    if (mounted) {
      setState(() {
        _shouldLoad = shouldLoad;
        if (!shouldLoad) {
          _hasBeenBlocked = true;
          widget.onLoadBlocked?.call();
        }
      });
      
      if (shouldLoad) {
        await _loadAudio();
      }
    }
  }

  Future<void> _updateConnectionStatus() async {
    final status = await NetworkGuard.getConnectionStatus();
    if (mounted) {
      setState(() => _connectionStatus = status);
    }
  }

  Future<void> _loadAudio() async {
    try {
      await _player.setUrl(widget.audioUrl);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  Future<void> _onTapToLoad() async {
    setState(() => _isLoading = true);
    
    // Override the cellular restriction for this asset
    final canLoad = await NetworkGuard.shouldLoadHeavyAsset(
      wifiOnlyPref: widget.wifiOnlyPref,
      assetKey: widget.audioUrl,
      forceLoad: true,
    );
    
    if (mounted && canLoad) {
      setState(() => _shouldLoad = true);
      await _loadAudio();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAudioBlockedOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.audiotrack,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio available',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect to Wi-Fi for auto-loading',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_connectionStatus != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _connectionStatus == 'Wi-Fi' ? Icons.wifi : Icons.signal_cellular_4_bar,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _connectionStatus!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_connectionStatus != null) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isLoading ? null : _onTapToLoad,
                icon: _isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.download, size: 16),
                label: Text(_isLoading ? 'Loading...' : 'Load Audio'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldLoad && _hasBeenBlocked) {
      return _buildAudioBlockedOverlay();
    }

    if (widget.builder != null) {
      return widget.builder!(context, _player, _shouldLoad);
    }

    // Default audio player UI
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;
        
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return const CircularProgressIndicator();
        } else if (playing != true) {
          return IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _shouldLoad ? _player.play : null,
          );
        } else if (processingState != ProcessingState.completed) {
          return IconButton(
            icon: const Icon(Icons.pause),
            onPressed: _player.pause,
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () => _player.seek(Duration.zero),
          );
        }
      },
    );
  }
}