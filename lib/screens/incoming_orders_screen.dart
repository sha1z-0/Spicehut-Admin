import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/printer_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/order_notification_service.dart';
import '../services/logger_service.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import '../widgets/printer_setup_guide_modal.dart';
import '../widgets/printer_status_chip.dart';

// Order Model
class Order {
  final String id;
  final String orderNumber;
  final DateTime dateTime;
  final String customerAvatar;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? orderType;
  final List<OrderItem> items;
  final double? tip;
  String status; // 'incoming', 'accepted', 'rejected'

  Order({
    required this.id,
    required this.orderNumber,
    required this.dateTime,
    required this.customerAvatar,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.orderType,
    required this.items,
    this.tip,
    this.status = 'incoming',
  });
}

class OrderItem {
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? spiceLevel;
  final bool isAlcohol;

  OrderItem({
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.spiceLevel,
    this.isAlcohol = false,
  });
}

class IncomingOrdersScreen extends StatefulWidget {
  const IncomingOrdersScreen({super.key});

  @override
  State<IncomingOrdersScreen> createState() => _IncomingOrdersScreenState();
}

class _IncomingOrdersScreenState extends State<IncomingOrdersScreen> with WidgetsBindingObserver {
  List<Order> _orders = [];
  bool _isLoading = false;
  int _newOrdersCount = 0;
  final Set<String> _knownOrderIds = {};

  String? _userLocation;
  bool _isAdmin = false;
  UserRole? _userRole;
  String? _selectedLocation;

  Timer? _timer;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OrderNotificationService.instance.setActiveScreen('incoming');
    _loadLocationAndOrders();
    // Poll every 10 seconds with mounted check for safety
    // This is the PRIMARY mechanism for detecting new orders on Vercel
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    OrderNotificationService.instance.setActiveScreen(null);
    super.dispose();
  }

  Future<void> _loadLocationAndOrders() async {
    final authService = AuthService();
    final role = await authService.getUserRole();
    final prefs = await SharedPreferences.getInstance();
    _userLocation = await authService.getUserLocation();

    setState(() {
      _isAdmin = role == UserRole.admin;
      _userRole = role;
    });

    if (_isAdmin) {
      _selectedLocation = prefs.getString('dashboard_selected_location');
    } else {
      _selectedLocation = _userLocation;
    }

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _connectSocket();
    _loadOrders();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app comes to foreground, check if location changed and reconnect socket if needed
      _checkLocationChanged();
    }
  }

  Future<void> _checkLocationChanged() async {
    if (!_isAdmin) return;
    
    final prefs = await SharedPreferences.getInstance();
    final newLocation = prefs.getString('dashboard_selected_location');
    
    if (newLocation != null && newLocation != _selectedLocation) {
      // Location changed, reconnect socket and reload orders
      _selectedLocation = newLocation;
      _connectSocket();
      _loadOrders();
    }
  }

  // This method will fetch orders from database
  Future<void> _loadOrders() async {
    if (!mounted) return;
    // Don't set isLoading on background polls to avoid UI flicker
    if (_orders.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // First, manually refresh stuck orders (calls backend to emit to all connected sockets)
      try {
        String refreshEndpoint = '/orders/refresh-incoming';
        if (_isAdmin && _selectedLocation != null) {
          refreshEndpoint += '?branch=$_selectedLocation';
        }
        await ApiService.post(refreshEndpoint, {});
      } catch (e) {
        // Ignore refresh errors - not fatal
        debugPrint('Refresh endpoint not available (normal for older backends)');
      }

      // Then fetch orders from backend - filter for 'incoming' status only
      String endpoint = '/orders?status=incoming';
      if (_isAdmin && _selectedLocation != null) {
        endpoint += '&branch=$_selectedLocation';
      }
      final response = await ApiService.get(endpoint);
      List<dynamic> ordersList = [];

      // Handle the response format from backend
      if (response is Map && response.containsKey('data')) {
        ordersList = response['data'] is List ? response['data'] : [];
      } else if (response is List) {
        ordersList = response;
      }

      if (ordersList.isNotEmpty) {
        final newOrders = ordersList
            .where((json) => json['status'] == 'incoming')
            .map((json) => _mapOrderFromJson(Map<String, dynamic>.from(json)))
            .toList();

        // Sort by date desc
        newOrders.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        final newIds = newOrders.map((order) => order.id).toSet();
        final trulyNewIds = newIds.difference(_knownOrderIds);
        final newCount = trulyNewIds.length;

        if (mounted) {
          setState(() {
            _orders = newOrders;
            _isLoading = false;
            _knownOrderIds
              ..clear()
              ..addAll(newIds);
            _newOrdersCount = newCount;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _orders = [];
            _isLoading = false;
            _knownOrderIds.clear();
            _newOrdersCount = 0;
          });
        }
      }
    } catch (e) {
      LoggerService.error('Error loading orders', e, null, 'IncomingOrders');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _connectSocket() {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) return;

    _socket?.disconnect();
    _socket?.dispose();

    // Socket.io configuration for Vercel serverless environment
    // IMPORTANT: Use polling-only transport because Vercel does NOT support persistent WebSocket connections!
    // WebSocket attempts will result in 400 errors on Vercel.
    _socket = io.io(
      ApiService.socketUrl,
      {
        // CRITICAL: Force polling transport for Vercel compatibility
        // Vercel cannot maintain persistent WebSocket connections (stateless serverless)
        'transports': ['polling'], // Polling only - no WebSocket upgrade!
        'autoConnect': false,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 99999,
        'upgrade': false, // CRITICAL: No WebSocket upgrade on Vercel!
        'timeout': 20000, // 20 second connection timeout
        'forceNew': true,
      },
    );

    // Connection event handlers
    _socket!.onConnect((_) {
      LoggerService.info('Socket.io connected via polling transport', 'IncomingOrders');
      _socket!.emit('join-branch', {'location': _selectedLocation});
    });

    _socket!.onConnectError((dynamic error) {
      LoggerService.error('Socket.io connection error', error, null, 'IncomingOrders');
    });

    _socket!.onError((dynamic error) {
      LoggerService.error('Socket.io error', error, null, 'IncomingOrders');
    });

    _socket!.onDisconnect((_) {
      LoggerService.warning('Socket.io disconnected, will auto-reconnect...', 'IncomingOrders');
    });

    // Listen for successful join confirmation
    _socket!.on('joined-branch', (data) {
      if (data is Map && data['success'] == true) {
        LoggerService.info('Successfully joined location room', 'IncomingOrders');
      } else {
        LoggerService.error('Failed to join location room', 'IncomingOrders');
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

  void _handleIncomingOrder(Map<String, dynamic> json) {
    if (!mounted) return;
    final order = _mapOrderFromJson(json);
    if (order.status != 'incoming') return;
    if (_knownOrderIds.contains(order.id)) return;

    setState(() {
      _orders.insert(0, order);
      _knownOrderIds.add(order.id);
      _newOrdersCount += 1;
    });

  }

  void _handleOrderUpdated(Map<String, dynamic> json) {
    if (!mounted) return;
    final order = _mapOrderFromJson(json);
    final index = _orders.indexWhere((o) => o.id == order.id);

    if (order.status == 'incoming') {
      if (index >= 0) {
        setState(() {
          _orders[index] = order;
        });
      } else if (!_knownOrderIds.contains(order.id)) {
        setState(() {
          _orders.insert(0, order);
          _knownOrderIds.add(order.id);
          _newOrdersCount += 1;
        });
      }
      return;
    }

    if (index >= 0) {
      setState(() {
        _orders.removeAt(index);
        _knownOrderIds.remove(order.id);
      });
    }
  }

  Order _mapOrderFromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'] ?? json['orderId'] ?? '',
      orderNumber: json['orderId'] ?? json['orderNumber'] ?? '#000',
      dateTime:
          (DateTime.tryParse(json['createdAt'] ?? json['dateTime'] ?? '') ??
              DateTime.now()).toLocal(),
      customerAvatar: json['customerAvatar'] ?? '👤',
      customerName: json['customerName'] ?? json['user']?['name'],
      customerPhone: json['customerPhone'] ?? json['user']?['phone'],
      customerAddress: json['customerAddress'] ?? (json['deliveryAddress'] != null ? json['deliveryAddress']['address'] : null),
      orderType: json['orderType'],
      tip: (json['tip'] as num?)?.toDouble(),
      status: json['status'] ?? 'incoming',
      items: (json['items'] as List?)
              ?.map((itemJson) => OrderItem(
                    name: itemJson['name'] ?? 'Unknown',
                    description: itemJson['description'] ?? '',
                    price: ((itemJson['price'] ?? 0) as num).toDouble(),
                    quantity: itemJson['quantity'] ?? 1,
                    imageUrl: itemJson['imageUrl'],
                    spiceLevel: itemJson['spiceLevel'] ?? itemJson['spice_level'],
                    isAlcohol: itemJson['isAlcohol'] == true,
                  ))
              .toList() ??
          [],
    );
  }

  // Accept order method
  Future<void> _acceptOrder(String orderId) async {
    final order = _orders.firstWhere((o) => o.id == orderId);

    try {
      final body = {
        'status': 'accepted',
        'branch': _selectedLocation ?? _userLocation
      };

      await ApiService.patch('/orders/$orderId', body);

      setState(() {
        order.status = 'accepted';
        _orders.removeWhere((o) => o.id == orderId);
        _knownOrderIds.remove(orderId);
        if (_newOrdersCount > 0) _newOrdersCount--;
      });

      final printResult = await PrinterService.printKitchenAndBillInParallel(
        orderId: order.orderNumber,
        items: order.items.map((i) => {
          'name': i.name,
          'quantity': i.quantity,
          'price': i.price,
          'spiceLevel': i.spiceLevel,
          'isAlcohol': i.isAlcohol,
        }).toList(),
        totalAmount: _calculateTotal(order.items),
        location: _selectedLocation ?? _userLocation ?? 'Main Kitchen',
        orderTime: order.dateTime,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        customerAddress: order.customerAddress,
        orderType: order.orderType,
        tip: order.tip,
        branchId: _selectedLocation ?? _userLocation,
      );

      if (mounted) {
        final failures = <String>[];
        if (!printResult.kitchenPrinted) {
          failures.add('Kitchen slip: ${printResult.kitchenError}');
        }
        if (!printResult.billPrinted) {
          failures.add('Bill slip: ${printResult.billError}');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failures.isEmpty
                  ? 'Order ${order.orderNumber} accepted and printed.'
                  : 'Order ${order.orderNumber} accepted. Print warning: ${failures.join(' | ')}',
            ),
            backgroundColor:
                failures.isEmpty ? const Color(0xFF4CAF50) : Colors.orange,
            duration: Duration(seconds: failures.isEmpty ? 2 : 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error accepting: $e')));
      }
    }
  }

  double _calculateTotal(List<OrderItem> items) {
    return items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  // Reject order method
  Future<void> _rejectOrder(String orderId) async {
    final order = _orders.firstWhere((o) => o.id == orderId);

    try {
      final body = {
        'status': 'rejected',
        'branch': _selectedLocation ?? _userLocation
      };

      await ApiService.patch('/orders/$orderId', body);

      setState(() {
        _orders.removeWhere((o) => o.id == orderId);
        _knownOrderIds.remove(orderId);
        if (_newOrdersCount > 0) _newOrdersCount--;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} rejected'),
            backgroundColor: const Color(0xFFFF6B9D),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error rejecting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Incoming Orders',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: PrinterStatusChip(
              roles: [PrinterRole.kitchen, PrinterRole.bill],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _loadOrders();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pulling incoming orders...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF5F5F5),
        child: SafeArea(
          child: Container(
            color: const Color(0xFFF5F5F5),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo/spicehut_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFFF7A00),
                                child: const Icon(
                                  Icons.restaurant,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SpiceHut',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7A00),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Dashboard
                if (_userRole != UserRole.staff)
                  _buildMenuItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                // Orders Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Online Orders',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Incoming',
                  isSelected: true,
                  onTap: () {},
                ),
                _buildMenuItem(
                  icon: Icons.history,
                  label: 'Order History',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (_userRole != UserRole.staff) ...[
                  // Analytics Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_userRole != UserRole.staff)
                  _buildMenuItem(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                // Restaurant Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Restaurant Orders',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.table_bar,
                  label: 'In-House Tables',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InHouseOrdersScreen(),
                      ),
                    );
                  },
                ),                _buildMenuItem(
                  icon: Icons.phone_in_talk,
                  label: 'On Call Orders',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnCallOrdersScreen(),
                      ),
                    );
                  },
                ),                if (_isAdmin)
                  _buildMenuItem(
                    icon: Icons.restaurant_menu,
                    label: 'Menu Management',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MenuManagementScreen(),
                        ),
                      );
                    },
                  ),
                // User Management (Admin Only)
                if (_isAdmin)
                  _buildMenuItem(
                    icon: Icons.people,
                    label: 'User Management',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                // Printer Setup Guide
                _buildMenuItem(
                  icon: Icons.print,
                  label: 'Printer Setup',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    DialogUtils.showAnimatedDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => const PrinterSetupGuideModal(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Log Out
                _buildMenuItem(
                  icon: Icons.logout,
                  label: 'Log Out',
                  isSelected: false,
                  textColor: const Color(0xFFFF7A00),
                  iconColor: const Color(0xFFFF7A00),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
                _buildMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  isSelected: false,
                  textColor: Colors.grey[600],
                  iconColor: Colors.grey[600],
                  onTap: () {
                    Navigator.pop(context);
                    ExternalLinks.openPrivacyPolicy();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7A00),
              ),
            )
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Incoming Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New orders will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF7A00),
                  onRefresh: _loadOrders,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE5D3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? (isSelected ? const Color(0xFFFF7A00) : Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? (isSelected ? const Color(0xFFFF7A00) : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isProcessing = order.status != 'incoming';
    final dateTimeFormatted = _formatDateTime(order.dateTime);

    final card = AnimatedOpacity(
      opacity: isProcessing ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isProcessing
              ? Border.all(
                  color: order.status == 'accepted'
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF6B9D),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${order.orderNumber}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateTimeFormatted,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                // Customer Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7FB5A5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      order.customerAvatar,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Order Items
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      // Food Image
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          image: item.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(item.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: item.imageUrl == null
                            ? Icon(
                                Icons.restaurant,
                                color: Colors.grey[400],
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Item Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '\$${item.price.toStringAsFixed(2)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Qty: ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: () => _showOrderDetailsDialog(order),
      child: card,
    );
  }

  void _showOrderDetailsDialog(Order order) {
    final isProcessing = order.status != 'incoming';
    final dateTimeFormatted = _formatDateTime(order.dateTime);
    final total = _calculateTotal(order.items) + (order.tip ?? 0);
    
    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order ${order.orderNumber}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(dateTimeFormatted, style: TextStyle(color: Colors.grey[600])),
              
              const SizedBox(height: 24),
              
              // Customer details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7FB5A5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          order.customerAvatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.customerName ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (order.customerPhone != null) Text(order.customerPhone!, style: TextStyle(color: Colors.grey[700])),
                          if (order.customerAddress != null) Text(order.customerAddress!, style: TextStyle(color: Colors.grey[700])),
                          if (order.orderType != null) Text('Type: ${order.orderType!.toUpperCase()}', style: const TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // Items list
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontSize: 16)),
                                if (item.spiceLevel != null) 
                                  Text('Spice: ${item.spiceLevel}', style: const TextStyle(color: Colors.red, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text('\$${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              
              const Divider(height: 32),
              
              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tip:', style: TextStyle(fontSize: 16)),
                  Text('\$${(order.tip ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF7A00))),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              if (isProcessing)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: order.status == 'accepted'
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status == 'accepted' ? 'Order Accepted' : 'Order Rejected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: order.status == 'accepted'
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF6B9D),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF6B9D),
                          side: const BorderSide(color: Color(0xFFFF6B9D)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectOrder(order.id);
                        },
                        child: const Text('REJECT ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _acceptOrder(order.id);
                        },
                        child: const Text('ACCEPT ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
