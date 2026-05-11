import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton HTTP Client Service with Keep-Alive support
/// Provides persistent HTTP connections for faster subsequent requests
class HttpClientService with WidgetsBindingObserver {
  // Singleton instance
  static HttpClientService? _instance;
  static HttpClientService get instance {
    _instance ??= HttpClientService._internal();
    return _instance!;
  }

  // Private constructor
  HttpClientService._internal() {
    _initializeClient();
    _setupConnectivityListener();
    _setupAppLifecycleListener();
  }

  // Persistent HTTP client
  http.Client? _client;
  
  // Keep-Alive configuration
  int _keepAliveTimeout = 30; // seconds
  static const int _maxConnections = 100;
  
  // Connectivity subscription
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // App state
  AppLifecycleState _appState = AppLifecycleState.resumed;

  /// Get the persistent HTTP client
  http.Client get client {
    _client ??= http.Client();
    return _client!;
  }

  /// Get Keep-Alive headers to add to requests
  Map<String, String> get keepAliveHeaders => {
    'Connection': 'keep-alive',
    'Keep-Alive': 'timeout=$_keepAliveTimeout, max=$_maxConnections',
  };

  /// Initialize the HTTP client
  void _initializeClient() {
    _client = http.Client();
    developer.log(
      'HttpClientService: Initialized persistent HTTP client with Keep-Alive (timeout: ${_keepAliveTimeout}s)',
      name: 'HttpClientService',
    );
  }

  /// Setup connectivity listener to handle network changes
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );
  }

  /// Setup app lifecycle listener
  void _setupAppLifecycleListener() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection = results.isNotEmpty && 
        !results.contains(ConnectivityResult.none);
    
    if (hasConnection) {
      // Network available - ensure client is ready
      developer.log(
        'HttpClientService: Network available, connection type: $results',
        name: 'HttpClientService',
      );
      
      // Recreate client on network change to establish fresh connections
      _recreateClient();
    } else {
      developer.log(
        'HttpClientService: No network connection',
        name: 'HttpClientService',
      );
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - use longer Keep-Alive timeout
        _keepAliveTimeout = 30;
        developer.log(
          'HttpClientService: App resumed, Keep-Alive timeout: ${_keepAliveTimeout}s',
          name: 'HttpClientService',
        );
        break;
        
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is in background - use shorter timeout for battery efficiency
        _keepAliveTimeout = 10;
        developer.log(
          'HttpClientService: App backgrounded, Keep-Alive timeout: ${_keepAliveTimeout}s',
          name: 'HttpClientService',
        );
        break;
        
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being closed - close the client
        closeClient();
        break;
    }
  }

  /// Recreate the HTTP client (useful after network changes)
  void _recreateClient() {
    _client?.close();
    _client = http.Client();
    developer.log(
      'HttpClientService: Recreated HTTP client',
      name: 'HttpClientService',
    );
  }

  /// Close the HTTP client
  void closeClient() {
    _client?.close();
    _client = null;
    developer.log(
      'HttpClientService: Closed HTTP client',
      name: 'HttpClientService',
    );
  }

  /// Get a fresh HTTP client for login requests (workaround for keep-alive issues)
  http.Client getFreshClient() {
    developer.log(
      'HttpClientService: Providing fresh HTTP client for login request',
      name: 'HttpClientService',
    );
    return http.Client();
  }

  /// Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    closeClient();
    _instance = null;
    developer.log(
      'HttpClientService: Disposed',
      name: 'HttpClientService',
    );
  }

  /// Force reconnect - useful when experiencing connection issues
  void forceReconnect() {
    _recreateClient();
  }

  /// Check if client is active
  bool get isClientActive => _client != null;

  /// Get current app state
  AppLifecycleState get appState => _appState;

  /// Get current Keep-Alive timeout
  int get currentKeepAliveTimeout => _keepAliveTimeout;
}

