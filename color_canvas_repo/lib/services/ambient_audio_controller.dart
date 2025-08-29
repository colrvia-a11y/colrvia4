import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Controls ambient audio looping with volume control and network awareness
class AmbientLoopController {
  AudioPlayer? _player;
  double _gain = 0.4;
  bool _isPlaying = false;
  String? _currentUrl;
  bool _autoplayBlocked = false;
  
  /// Start playing ambient audio loop
  Future<void> start(String loopUrl, double gain) async {
    try {
      _gain = gain;
      _currentUrl = loopUrl;
      _autoplayBlocked = false;
      
      // Initialize player if needed
      _player ??= AudioPlayer();
      
      // Set up the audio
      await _player!.setUrl(loopUrl);
      await _player!.setVolume(_gain);
      await _player!.setLoopMode(LoopMode.one);
      
      // Attempt to play (may fail due to autoplay policies)
      try {
        await _player!.play();
        _isPlaying = true;
        debugPrint('🎵 Ambient audio started successfully');
      } catch (e) {
        // Autoplay blocked - this is expected in many browsers
        _autoplayBlocked = true;
        _isPlaying = false;
        debugPrint('🎵 Ambient audio autoplay blocked: $e');
      }
    } catch (e) {
      debugPrint('🎵 Error starting ambient audio: $e');
      _autoplayBlocked = true;
    }
  }
  
  /// Stop ambient audio
  Future<void> stop() async {
    try {
      if (_player != null) {
        await _player!.stop();
        _isPlaying = false;
        debugPrint('🎵 Ambient audio stopped');
      }
    } catch (e) {
      debugPrint('🎵 Error stopping ambient audio: $e');
    }
  }
  
  /// Pause ambient audio (for app backgrounding)
  Future<void> pause() async {
    try {
      if (_player != null && _isPlaying) {
        await _player!.pause();
        debugPrint('🎵 Ambient audio paused');
      }
    } catch (e) {
      debugPrint('🎵 Error pausing ambient audio: $e');
    }
  }
  
  /// Resume ambient audio
  Future<void> resume() async {
    try {
      if (_player != null && !_isPlaying) {
        await _player!.play();
        _isPlaying = true;
        debugPrint('🎵 Ambient audio resumed');
      }
    } catch (e) {
      debugPrint('🎵 Error resuming ambient audio: $e');
    }
  }
  
  /// Set volume/gain
  Future<void> setGain(double gain) async {
    try {
      _gain = gain;
      if (_player != null) {
        await _player!.setVolume(_gain);
        debugPrint('🎵 Ambient audio gain set to $_gain');
      }
    } catch (e) {
      debugPrint('🎵 Error setting ambient audio gain: $e');
    }
  }
  
  /// Manually start playback (for user-initiated play after autoplay block)
  Future<void> manualPlay() async {
    try {
      if (_player != null && _currentUrl != null) {
        await _player!.play();
        _isPlaying = true;
        _autoplayBlocked = false;
        debugPrint('🎵 Ambient audio started manually');
      }
    } catch (e) {
      debugPrint('🎵 Error with manual ambient audio play: $e');
    }
  }
  
  /// Check if autoplay was blocked
  bool get isAutoplayBlocked => _autoplayBlocked;
  
  /// Check if currently playing
  bool get isPlaying => _isPlaying;
  
  /// Current gain level
  double get currentGain => _gain;
  
  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await _player?.dispose();
      _player = null;
      _isPlaying = false;
      debugPrint('🎵 Ambient audio controller disposed');
    } catch (e) {
      debugPrint('🎵 Error disposing ambient audio controller: $e');
    }
  }
}