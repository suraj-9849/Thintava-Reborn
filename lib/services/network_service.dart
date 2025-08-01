// lib/services/network_service.dart - NEW FILE FOR NETWORK MANAGEMENT
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool get isConnected => _connectionStatus != ConnectivityResult.none;
  bool get isWifi => _connectionStatus == ConnectivityResult.wifi;
  bool get isMobile => _connectionStatus == ConnectivityResult.mobile;
  bool get isEthernet => _connectionStatus == ConnectivityResult.ethernet;
  
  ConnectivityResult get connectionStatus => _connectionStatus;
  
  String get connectionType {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
      default:
        return 'No Connection';
    }
  }

  /// Initialize network monitoring
  Future<void> initialize() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          debugPrint('❌ Connectivity stream error: $error');
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing network service: $e');
    }
  }

  /// Update connection status
  void _updateConnectionStatus(ConnectivityResult result) {
    final oldStatus = _connectionStatus;
    _connectionStatus = result;
    
    debugPrint('🌐 Network status changed: ${oldStatus.name} → ${result.name}');
    
    notifyListeners();
  }

  /// Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return isConnected;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Wait for network connection
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (isConnected) return true;
    
    final completer = Completer<bool>();
    StreamSubscription? subscription;
    Timer? timer;
    
    subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        subscription?.cancel();
        timer?.cancel();
        completer.complete(true);
      }
    });
    
    timer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    
    return completer.future;
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Get network quality estimation
  NetworkQuality getNetworkQuality() {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return NetworkQuality.good;
      case ConnectivityResult.mobile:
        return NetworkQuality.fair; // Could be 3G, 4G, or 5G
      case ConnectivityResult.vpn:
        return NetworkQuality.fair;
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.other:
        return NetworkQuality.poor;
      case ConnectivityResult.none:
      default:
        return NetworkQuality.none;
    }
  }

  /// Get user-friendly network message
  String getNetworkMessage() {
    switch (getNetworkQuality()) {
      case NetworkQuality.good:
        return 'Strong connection detected';
      case NetworkQuality.fair:
        return 'Moderate connection - some features may be slower';
      case NetworkQuality.poor:
        return 'Weak connection - please be patient';
      case NetworkQuality.none:
        return 'No internet connection available';
    }
  }

  /// Check if network is suitable for payments
  bool isSuitableForPayments() {
    return isConnected && getNetworkQuality() != NetworkQuality.poor;
  }
}

enum NetworkQuality {
  good,    // WiFi, Ethernet
  fair,    // Mobile data, VPN
  poor,    // Bluetooth, Other
  none,    // No connection
}