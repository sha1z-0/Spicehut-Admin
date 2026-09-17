import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'auth_service.dart';
import 'logger_service.dart';

class OrderNotificationService with WidgetsBindingObserver {
  OrderNotificationService._();

  static final OrderNotificationService instance = OrderNotificationService._();
  static const String _logTag = 'OrderNotificationService';

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _knownOrderIds = {};
  final Map<String, DateTime> _recentNotifyByOrder = {};
  final Set<String> _notifiedOrders = {};

  io.Socket? _socket;
  Timer? _ringTimer;
  Timer? _refreshTimer;
  Timer? _httpPollTimer;
  Timer? _bannerTimer;
  OverlayEntry? _overlayEntry;
  GlobalKey<NavigatorState>? _navigatorKey;
  DateTime? _lastRingAt;
  bool _initialized = false;
  bool _isRinging = false;
  String? _currentLocation;

  bool _connected = false;
  String? _activeScreen;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  String? _pendingBannerMessage;
  bool _pendingRingtone = false;

  bool get isConnected => _connected;
  bool get isIncomingActive => _activeScreen == 'incoming';

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    _disconnectSocket();
    _refreshTimer?.cancel();
    _httpPollTimer?.cancel();
    // Socket.io reconnection timer (secondary/fallback)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _connectIfReady();
    });
    // PRIMARY: HTTP polling for new orders (works reliably on Vercel)
    _httpPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollForNewOrders();
    });
    await _connectIfReady();
    // Initial HTTP poll
    await _pollForNewOrders();
  }

  void setActiveScreen(String? screen) {
    _activeScreen = screen;
  }

  Future<void> dispose() async {
    _initialized = false;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _httpPollTimer?.cancel();
    _ringTimer?.cancel();
    _bannerTimer?.cancel();
    _overlayEntry?.remove();
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _socket?.disconnect();
    _socket?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      if (_pendingRingtone) {
        _pendingRingtone = false;
        _playRingtone();
      }
      if (_pendingBannerMessage != null) {
        final message = _pendingBannerMessage!;
        _pendingBannerMessage = null;
        _showBanner(message);
      }
    }
  }

  Future<void> _connectIfReady() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      _disconnectSocket();
      return;
    }

    final authService = AuthService();
    final role = await authService.getUserRole();
    final userLocation = await authService.getUserLocation();
    String? selectedLocation;

    if (role == UserRole.admin) {
      selectedLocation = prefs.getString('dashboard_selected_location');
    } else {
      selectedLocation = userLocation;
    }

    if (selectedLocation == null || selectedLocation.isEmpty) {
      _disconnectSocket();
      return;
    }

    if (_currentLocation != selectedLocation) {
      _currentLocation = selectedLocation;
      _knownOrderIds.clear();
      _notifiedOrders.clear();
      _recentNotifyByOrder.clear();
      _disconnectSocket();
    }

    if (_socket != null) {
      if (_socket!.connected) {
        return;
      }
      _socket!.off('order:new');
      _socket!.off('order:updated');
      _socket!.off('joined-branch');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    // Socket.io configuration for Vercel serverless environment
    // IMPORTANT: Use polling-only transport because Vercel does NOT support persistent WebSocket connections!
    // WebSocket upgrades will fail with 400 errors on Vercel.
    _socket = io.io(
      ApiService.socketUrl,
      {
        // CRITICAL: Force polling transport for Vercel compatibility
        // Vercel cannot maintain persistent WebSocket connections (stateless serverless)
        'transports': ['polling'], // Polling only - no WebSocket upgrade!
        'autoConnect': false,
        'forceNew': true,
        'upgrade': false, // CRITICAL: No WebSocket upgrade attempts on Vercel!
        'timeout': 20000, // 20 second connection timeout
        
        // Aggressive reconnection for Vercel's unreliable serverless environment
        'reconnection': true,
        'reconnectionDelay': 500,  // Start with 500ms
        'reconnectionDelayMax': 5000,  // Max 5 seconds
        'reconnectionAttempts': 99999,  // Infinite retries
        'rememberUpgrade': false,  // Don't try to remember WebSocket
      },
    );

    _socket!.onConnect((_) {
      _connected = true;
      LoggerService.info(
        'Socket connected via polling transport to $selectedLocation',
        _logTag,
      );
      _socket!.emit('join-branch', {'location': selectedLocation});
    });

    _socket!.onConnectError((dynamic error) {
      _connected = false;
      LoggerService.warning('Socket connection error: $error', _logTag);
    });

    _socket!.onError((dynamic error) {
      LoggerService.warning('Socket error: $error', _logTag);
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      LoggerService.info('Socket disconnected, will auto-reconnect', _logTag);
    });

    // Listen for successful join confirmation
    _socket!.on('joined-branch', (data) {
      if (data is Map && data['success'] == true) {
        LoggerService.info('Joined location room successfully', _logTag);
      } else {
        LoggerService.warning(
          'Failed to join location room: ${data?['error']}',
          _logTag,
        );
      }
    });

    // Listen for new orders
    _socket!.on('order:new', (data) {
      if (data is Map) {
        _handleIncomingOrder(Map<String, dynamic>.from(data));
      }
    });

    // Listen for order updates
    _socket!.on('order:updated', (data) {
      if (data is Map) {
        _handleOrderUpdated(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void _disconnectSocket() {
    _connected = false;
    _socket?.disconnect();
  }

  /// PRIMARY notification mechanism: HTTP polling for new orders.
  /// This works reliably on Vercel serverless (unlike Socket.io which needs sticky sessions).
  Future<void> _pollForNewOrders() async {
    if (_currentLocation == null || _currentLocation!.isEmpty) return;
    try {
      final endpoint = '/orders?status=incoming&branch=$_currentLocation';
      final response = await ApiService.get(endpoint);
      List<dynamic> ordersList = [];
      if (response is Map && response.containsKey('data')) {
        ordersList = response['data'] is List ? response['data'] : [];
      } else if (response is List) {
        ordersList = response;
      }

      final incomingOrders = ordersList
          .where((json) => json['status'] == 'incoming')
          .toList();

      for (final json in incomingOrders) {
        final id = json['_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (!_knownOrderIds.contains(id)) {
          // New order detected via HTTP polling!
          _knownOrderIds.add(id);
          final orderNumber = json['orderNumber']?.toString();
          if (_shouldNotifyKeys(id, orderNumber)) {
            LoggerService.info(
              'HTTP poll detected new order: $orderNumber ($id)',
              _logTag,
            );
            _notifyNewOrder('New incoming order ${orderNumber ?? id}');
          }
        }
      }

      // Clean up: remove orders no longer in the incoming list
      final currentIds = incomingOrders.map((j) => j['_id']?.toString() ?? '').toSet();
      _knownOrderIds.retainAll(currentIds);
    } catch (e) {
      // Silently fail - HTTP polling errors shouldn't crash the app
      LoggerService.warning('HTTP poll error: $e', _logTag);
    }
  }

  /// Called by IncomingOrdersScreen when it detects new orders via its own HTTP polling.
  /// This ensures the ringtone plays even if this service's poll hasn't fired yet.
  void notifyNewOrderDetected(String orderId, String? orderNumber) {
    if (orderId.isEmpty) return;
    if (_knownOrderIds.contains(orderId)) return;
    _knownOrderIds.add(orderId);
    if (_shouldNotifyKeys(orderId, orderNumber)) {
      LoggerService.debug(
        'New order detected from screen: $orderNumber ($orderId)',
        _logTag,
      );
      _notifyNewOrder('New incoming order ${orderNumber ?? orderId}');
    }
  }

  void _handleIncomingOrder(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'incoming';
    if (status != 'incoming') return;
    final id = json['_id']?.toString() ?? json['orderId']?.toString() ?? '';
    if (id.isEmpty || _knownOrderIds.contains(id)) return;

    _knownOrderIds.add(id);
    final orderNumber = json['orderNumber']?.toString();
    if (_shouldNotifyKeys(id, orderNumber)) {
      _notifyNewOrder('New incoming order ${json['orderNumber'] ?? id}');
    }
  }

  void _notifyNewOrder(String message) {
    if (_appLifecycleState != AppLifecycleState.resumed) {
      _pendingRingtone = true;
      _pendingBannerMessage = message;
      return;
    }

    _playRingtone();
    _showBanner(message);
  }

  void _handleOrderUpdated(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    final id = json['_id']?.toString() ?? json['orderId']?.toString() ?? '';
    if (id.isEmpty) return;

    if (status == 'incoming') {
      if (!_knownOrderIds.contains(id)) {
        _knownOrderIds.add(id);
      }
    } else {
      _knownOrderIds.remove(id);
      _notifiedOrders.remove(id);
    }
  }

  bool _shouldNotifyKeys(String orderId, String? orderNumber) {
    if (_notifiedOrders.contains(orderId) ||
        (orderNumber != null && _notifiedOrders.contains(orderNumber))) {
      return false;
    }
    final now = DateTime.now();
    _recentNotifyByOrder.removeWhere(
      (_, time) => now.difference(time).inSeconds > 30,
    );
    final last = _recentNotifyByOrder[orderId] ??
        (orderNumber != null ? _recentNotifyByOrder[orderNumber] : null);
    if (last != null && now.difference(last).inMilliseconds < 1500) {
      return false;
    }
    _recentNotifyByOrder[orderId] = now;
    _notifiedOrders.add(orderId);
    if (orderNumber != null && orderNumber.isNotEmpty) {
      _recentNotifyByOrder[orderNumber] = now;
      _notifiedOrders.add(orderNumber);
    }
    return true;
  }

  Future<void> _playRingtone() async {
    try {
      if (_isRinging) {
        return;
      }
      final now = DateTime.now();
      if (_lastRingAt != null &&
          now.difference(_lastRingAt!).inMilliseconds < 1500) {
        return;
      }
      _lastRingAt = now;
      _isRinging = true;
      _ringTimer?.cancel();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      _ringTimer = Timer(const Duration(seconds: 10), () async {
        await _audioPlayer.stop();
        _isRinging = false;
      });
    } catch (_) {
      // ignore audio errors
      _isRinging = false;
    }
  }

  void _showBanner(String message) {
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry?.remove();
    _bannerTimer?.cancel();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: const ValueKey('new-order-banner'),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _overlayEntry?.remove();
              _overlayEntry = null;
              _bannerTimer?.cancel();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    _bannerTimer = Timer(const Duration(seconds: 4), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
}
