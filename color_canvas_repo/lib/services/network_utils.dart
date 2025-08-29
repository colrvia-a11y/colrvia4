import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced NetworkGuard utility for managing Wi-Fi only media policies
class NetworkGuard {
  static final Connectivity _connectivity = Connectivity();
  
  /// Track session-based overrides for cellular loading
  static final Set<String> _cellularOverridesThisSession = <String>{};
  
  /// Check if device is currently on Wi-Fi
  static Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
  
  /// Check if device is on cellular data
  static Future<bool> isCellular() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile) && 
           !results.contains(ConnectivityResult.wifi);
  }
  
  /// Check if device has any connectivity
  static Future<bool> hasConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
  
  /// Check if heavy asset should be loaded based on network policy
  /// 
  /// Parameters:
  /// - [wifiOnlyPref]: User preference for Wi-Fi only assets
  /// - [assetKey]: Unique identifier for the asset (for session tracking)
  /// - [forceLoad]: Override policy and load anyway
  /// 
  /// Returns:
  /// - [true] if asset should load automatically
  /// - [false] if asset should show tap-to-load overlay
  static Future<bool> shouldLoadHeavyAsset({
    required bool wifiOnlyPref,
    required String assetKey,
    bool forceLoad = false,
  }) async {
    // If user doesn't have Wi-Fi only preference enabled, always load
    if (!wifiOnlyPref) return true;
    
    // If force load is requested (user tapped to load), allow it
    if (forceLoad) {
      _cellularOverridesThisSession.add(assetKey);
      return true;
    }
    
    // If already overridden this session, allow loading
    if (_cellularOverridesThisSession.contains(assetKey)) {
      return true;
    }
    
    // Check network status
    final wifi = await isWifi();
    
    // On Wi-Fi, always load
    if (wifi) return true;
    
    // On cellular with Wi-Fi only preference, don't auto-load
    return false;
  }
  
  /// Mark an asset as approved for cellular loading in this session
  static void overrideCellularForAsset(String assetKey) {
    _cellularOverridesThisSession.add(assetKey);
  }
  
  /// Clear all session overrides (call when app starts or user logs out)
  static void clearSessionOverrides() {
    _cellularOverridesThisSession.clear();
  }
  
  /// Get a stream of connectivity changes
  static Stream<List<ConnectivityResult>> get connectivityStream => 
      _connectivity.onConnectivityChanged;
  
  /// Get current connectivity status as a human-readable string
  static Future<String> getConnectionStatus() async {
    final results = await _connectivity.checkConnectivity();
    
    if (results.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 'Cellular';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else {
      return 'No Connection';
    }
  }
}

/// Legacy class for backward compatibility
@Deprecated('Use NetworkGuard instead')
class NetworkUtils {
  static Future<bool> isWifi() async {
    return NetworkGuard.isWifi();
  }
}