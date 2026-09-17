import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../services/printer_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'dashboard_screen.dart';
import 'incoming_orders_screen.dart';
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'sign_in_screen.dart';
import 'in_house_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import '../widgets/printer_setup_guide_modal.dart';
import '../widgets/printer_status_chip.dart';
import '../widgets/spice_level_picker_dialog.dart';

class OnCallOrdersScreen extends StatefulWidget {
  const OnCallOrdersScreen({super.key});

  @override
  State<OnCallOrdersScreen> createState() => _OnCallOrdersScreenState();
}

class _OnCallOrdersScreenState extends State<OnCallOrdersScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _orders = [];
  String? _selectedLocation;
  String? _userName;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadLocationAndOrders();
  }

  Future<void> _loadLocationAndOrders() async {
    final authService = AuthService();
    final role = await authService.getUserRole();
    final location = await authService.getUserLocation();
    final prefs = await SharedPreferences.getInstance();

    String? name;
    try {
      name = await authService.getUserName();
    } catch (e) {
      debugPrint('Error getting user name: $e');
    }

    setState(() {
      _isAdmin = role == UserRole.admin;
      _userName = name;
    });

    if (role == UserRole.admin) {
      _selectedLocation = prefs.getString('dashboard_selected_location');
    } else {
      _selectedLocation = location;
    }

    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get(
        '/inhouse-orders?branch=$_selectedLocation&orderType=oncall',
      );

      if (response is Map && response['data'] != null) {
        setState(() {
          _orders = (response['data'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  void _showPlaceOrderDialog() {
    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Place New Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delivery_dining, color: Color(0xFFFF7A00)),
              title: const Text('Delivery'),
              onTap: () {
                Navigator.pop(context);
                _createOrder('delivery');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shopping_bag, color: Color(0xFFFF7A00)),
              title: const Text('Takeaway'),
              onTap: () {
                Navigator.pop(context);
                _createOrder('takeaway');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrder(String deliveryType) async {
    // Show order creation screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _OrderCreationScreen(
          deliveryType: deliveryType,
          location: _selectedLocation!,
        ),
      ),
    );

    if (result == true) {
      _loadOrders();
    }
  }

  Future<void> _billOrder(Map<String, dynamic> order) async {
    final tipController = TextEditingController(text: '0');
    String? paymentMethod = 'cash';

    final confirmed = await DialogUtils.showAnimatedDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Bill Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total: \$${((order['totalAmount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: paymentMethod,
                onChanged: (value) {
                  setState(() {
                    paymentMethod = value;
                  });
                },
                child: const Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Cash'),
                        value: 'cash',
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Card'),
                        value: 'card',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tipController,
                decoration: const InputDecoration(
                  labelText: 'Tip Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final orderToken = order['orderToken'];
      final totalAmount = ((order['totalAmount'] as num?)?.toDouble() ?? 0.0);
      final tip = double.tryParse(tipController.text) ?? 0.0;
      final billAmount = totalAmount + tip;

      await ApiService.patch(
        '/inhouse-orders/$orderToken?branch=$_selectedLocation',
        {
          'status': 'billed',
          'paymentMethod': paymentMethod,
          'tip': tip,
          'billAmount': billAmount,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order billed successfully')),
        );
      }
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error billing order: $e')),
        );
      }
    } finally {
      tipController.dispose();
    }
  }
  Future<void> _reprintKitchenSlip(Map<String, dynamic> order) async {
    try {
      final orderId = order['orderNumber'] ?? order['_id'];
      final items = order['items'] as List? ?? [];
      final orderType = order['orderType'];
      
      await PrinterService.printKitchenSlip(
        orderId.toString(),
        items,
        location: _selectedLocation ?? 'Main Kitchen',
        orderTime: order['createdAt'] != null 
            ? DateTime.parse(order['createdAt']).toLocal() 
            : DateTime.now(),
        orderType: orderType,
        waiterName: _userName,
        branchId: _selectedLocation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitchen slip printed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing kitchen slip: $e')),
        );
      }
    }
  }

  Future<void> _reprintBillSlip(Map<String, dynamic> order) async {
    try {
      final orderId = order['orderNumber'] ?? order['_id'];
      final totalAmount = ((order['totalAmount'] as num?)?.toDouble() ?? 0.0);
      final tip = ((order['tip'] as num?)?.toDouble() ?? 0.0);
      final items = order['items'] as List? ?? [];
      final customerName = order['customerName'];
      final orderType = order['orderType'];

      LoggerService.info(
        'Reprint bill requested for ${orderId.toString()}.',
        'OnCallOrders',
      );
      
      await PrinterService.printBillSlip(
        orderId.toString(),
        totalAmount,
        items: items.cast<Map<String, dynamic>>(),
        customerName: customerName,
        tip: tip > 0 ? tip : null,
        orderType: orderType,
        waiterName: _userName,
        branchId: _selectedLocation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill slip printed successfully')),
        );
      }
    } catch (e) {
      LoggerService.error('Error printing bill slip', e, null, 'OnCallOrders');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing bill slip: $e')),
        );
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
          'On Call Orders',
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
            onPressed: _loadOrders,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPlaceOrderDialog,
        backgroundColor: const Color(0xFFFF7A00),
        icon: const Icon(Icons.add),
        label: const Text('Place Order'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No on-call orders',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFFF7A00),
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final deliveryType = order['deliveryType'] ?? 'unknown';
    final customerName = order['customerName'] ?? 'Guest';
    final customerPhone = order['customerPhone'] ?? '';
    final items = order['items'] as List? ?? [];
    final total = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] ?? 'pending';
    final createdAt = order['createdAt'] != null
        ? DateTime.parse(order['createdAt']).toLocal()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  deliveryType == 'delivery'
                      ? Icons.delivery_dining
                      : Icons.shopping_bag,
                  color: const Color(0xFFFF7A00),
                ),
                const SizedBox(width: 8),
                Text(
                  deliveryType.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'billed'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: status == 'billed' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              customerName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (customerPhone.isNotEmpty)
              Text(
                customerPhone,
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('${item['quantity']}x ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(item['name'] ?? '')),
                      Text(
                        '\$${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${_formatTime(createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (status != 'billed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reprintKitchenSlip(order),
                      icon: const Icon(Icons.print),
                      label: const Text('Kitchen Slip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reprintBillSlip(order),
                      icon: const Icon(Icons.receipt),
                      label: const Text('Print Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _billOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Bill Order',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: Container(
          color: const Color(0xFFF5F5F5),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
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
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IncomingOrdersScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.history,
                label: 'Order History',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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
              _buildMenuItem(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InHouseOrdersScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.phone_in_talk,
                label: 'On Call Orders',
                isSelected: true,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (_isAdmin)
                _buildMenuItem(
                  icon: Icons.restaurant_menu,
                  label: 'Menu Management',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MenuManagementScreen(),
                      ),
                    );
                  },
                ),
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
}

// ============================================================================
// ORDER CREATION SCREEN
// ============================================================================

class _OrderCreationScreen extends StatefulWidget {
  final String deliveryType;
  final String location;

  const _OrderCreationScreen({
    required this.deliveryType,
    required this.location,
  });

  @override
  State<_OrderCreationScreen> createState() => _OrderCreationScreenState();
}

class _OrderCreationScreenState extends State<_OrderCreationScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  List<MenuItem> _menuItems = [];
  final List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = false;
  Map<String, dynamic>? _createdOrder;
  bool _showPrintButtons = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final name = await AuthService().getUserName();
      if (mounted) {
        setState(() {
          _userName = name;
        });
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('/menu?branch=${widget.location}');
      if (response is Map && response['data'] != null) {
        setState(() {
          _menuItems = (response['data'] as List)
              .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem(MenuItem item) async {
    final spiceLevel = await SpiceLevelPickerDialog.show(context);
    if (!mounted) return;

    setState(() {
      final existingIndex = _orderItems.indexWhere(
        (e) =>
            e['_id'] == item.id &&
            (e['spiceLevel'] ?? e['spice_level']) == spiceLevel,
      );
      if (existingIndex >= 0) {
        _orderItems[existingIndex]['quantity']++;
      } else {
        _orderItems.add({
          '_id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': 1,
          'spiceLevel': spiceLevel,
          'isAlcohol': item.isAlcohol,
        });
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_orderItems[index]['quantity'] > 1) {
        _orderItems[index]['quantity']--;
      } else {
        _orderItems.removeAt(index);
      }
    });
  }

  double get _total {
    return _orderItems.fold(0.0, (sum, item) {
      return sum + ((item['price'] as num) * (item['quantity'] as num)).toDouble();
    });
  }

  Future<void> _saveOrder() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the order')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.post('/inhouse-orders', {
        'branch': widget.location,
        'customerName': _customerNameController.text,
        'customerPhone': _customerPhoneController.text,
        'customerAddress': _customerAddressController.text,
        'items': _orderItems,
        'totalAmount': _total,
        'orderType': 'oncall',
        'deliveryType': widget.deliveryType,
        'status': 'pending',
      });

      if (mounted) {
        // Capture the created order from response
        if (response is Map && response['data'] != null) {
          setState(() {
            _createdOrder = Map<String, dynamic>.from(response['data']);
            _showPrintButtons = true;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order created successfully')),
          );
        } else {
          // Fallback if response structure is different
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating order: $e')),
        );
      }
    }
  }

  Future<void> _printKitchenSlip() async {
    if (_createdOrder == null) return;

    try {
      final orderId = _createdOrder!['orderNumber'] ?? _createdOrder!['_id'];
      await PrinterService.printKitchenSlip(
        orderId.toString(),
        _orderItems,
        location: widget.location,
        orderTime: DateTime.now(),
        orderType: widget.deliveryType,
        waiterName: _userName,
        branchId: widget.location,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitchen slip printed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing kitchen slip: $e')),
        );
      }
    }
  }

  Future<void> _printBillSlip() async {
    if (_createdOrder == null) return;

    try {
      final orderId = _createdOrder!['orderNumber'] ?? _createdOrder!['_id'];
      final totalAmount = _total;

      LoggerService.info(
        'Print bill requested for ${orderId.toString()} (${widget.location}).',
        'OnCallOrders',
      );
      
      await PrinterService.printBillSlip(
        orderId.toString(),
        totalAmount,
        items: _orderItems,
        customerName: _customerNameController.text,
        orderType: widget.deliveryType,
        waiterName: _userName,
        branchId: widget.location,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill slip printed successfully')),
        );
      }
    } catch (e) {
      LoggerService.error('Error printing bill slip', e, null, 'OnCallOrders');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing bill slip: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        title: Text('${widget.deliveryType.toUpperCase()} Order'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.deliveryType == 'delivery')
                          TextField(
                            controller: _customerAddressController,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Address',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          'Order Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_orderItems.isNotEmpty)
                          ..._orderItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item['name']),
                                subtitle: Text('\$${item['price']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item['quantity']}x',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () => _removeItem(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 16),
                        const Text(
                          'Add Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._menuItems.map((item) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item.name),
                                subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Color(0xFFFF7A00)),
                                  onPressed: () => _addItem(item),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF7A00),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_showPrintButtons)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _printKitchenSlip,
                                icon: const Icon(Icons.print),
                                label: const Text('Print Kitchen Slip'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _printBillSlip,
                                icon: const Icon(Icons.receipt),
                                label: const Text('Print Bill'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(Icons.done),
                                label: const Text('Done'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A00),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A00),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Order',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }
}
