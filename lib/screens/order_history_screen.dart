import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'incoming_orders_screen.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import 'sign_in_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/printer_setup_guide_modal.dart';

// Order History Model
class HistoricalOrder {
  final String id;
  final String orderNumber;
  final DateTime dateTime;
  final String location;
  final String status; // 'accepted', 'rejected', 'completed', 'failed'
  final List<OrderHistoryItem> items;
  final double totalAmount;

  HistoricalOrder({
    required this.id,
    required this.orderNumber,
    required this.dateTime,
    required this.location,
    required this.status,
    required this.items,
    required this.totalAmount,
  });
}

class OrderHistoryItem {
  final String name;
  final String description;
  final double price;
  final int quantity;

  OrderHistoryItem({
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
  });
}

// Chart Data Model
class DailyOrderData {
  final String day;
  final int afternoonOrders;
  final int nightOrders;

  DailyOrderData({
    required this.day,
    required this.afternoonOrders,
    required this.nightOrders,
  });
}

// Monthly Order Data Model
class MonthlyOrderData {
  final String month;
  final int orders;

  MonthlyOrderData({
    required this.month,
    required this.orders,
  });
}

// Yearly Order Data Model
class YearlyOrderData {
  final String year;
  final int orders;

  YearlyOrderData({
    required this.year,
    required this.orders,
  });
}

class _ChartRow {
  final String label;
  final int orders;

  const _ChartRow({required this.label, required this.orders});
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<HistoricalOrder> _orders = [];
  List<DailyOrderData> _chartData = [];
  List<MonthlyOrderData> _monthlyChartData = [];
  List<YearlyOrderData> _yearlyChartData = [];
  bool _isLoading = false;
  String _chartPeriod = 'Days'; // 'Days', 'Months', 'Years'
  bool _isAdmin = false;
  UserRole? _userRole;

  // Filter state
  String _filterType = 'Day'; // 'Day', 'Month', 'Year'
  String _selectedFilterValue = '';
  String _selectedTime = 'All';
  List<String> _availableDates = [];
  List<String> _availableMonths = [];
  List<String> _availableYears = [];
  static const List<String> _times = [
    'All',
    'Morning',
    'Afternoon',
    'Evening',
    'Night'
  ];
  final ScrollController _chartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  String? _userLocation;
  String? _selectedLocation;

  Future<void> _loadInitialData() async {
    final authService = AuthService();
    final role = await authService.getUserRole();
    final prefs = await SharedPreferences.getInstance();
    final location = await authService.getUserLocation();

    setState(() {
      _isAdmin = role == UserRole.admin;
      _userRole = role;
      _userLocation = location;
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

    await _loadOrders();
    await _loadChartData();
    _buildAvailableDates();
  }

  void _buildAvailableDates() {
    final now = DateTime.now();
    final dates = <String>[];
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      dates.add(
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    }
    setState(() {
      _availableDates = dates;
      _selectedFilterValue = _availableDates.first;
      _buildAvailableMonths();
      _buildAvailableYears();
    });
  }

  void _buildAvailableMonths() {
    final now = DateTime.now();
    final months = <String>[];
    const monthNames = [
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

    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year - (i ~/ 12), now.month - (i % 12), 1);
      if (date.month >= 1) {
        months.add('${monthNames[date.month - 1]} ${date.year}');
      }
    }
    setState(() {
      _availableMonths = months;
    });
  }

  void _buildAvailableYears() {
    final now = DateTime.now();
    final years = <String>[];

    for (int i = 0; i < 5; i++) {
      years.add((now.year - i).toString());
    }
    setState(() {
      _availableYears = years;
    });
  }

  // Load order history from database
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch order history from backend
      String endpoint = '/orders/history';
      if (_isAdmin && _selectedLocation != null) {
        endpoint += '?branch=$_selectedLocation';
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
        final orders = ordersList.map((json) {
          return HistoricalOrder(
            id: json['_id'] ?? json['orderId'] ?? '',
            orderNumber: json['orderId'] ?? json['orderNumber'] ?? '#000',
            dateTime: (DateTime.tryParse(
                    json['createdAt'] ?? json['dateTime'] ?? '') ??
                DateTime.now()).toLocal(),
            location:
              json['location'] ?? json['branch'] ?? _selectedLocation ?? '',
            status: json['status'] ?? 'accepted',
            totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
            items: (json['items'] as List?)
                    ?.map((itemJson) => OrderHistoryItem(
                          name: itemJson['name'] ?? 'Unknown',
                          description: itemJson['description'] ?? '',
                          price: ((itemJson['price'] ?? 0) as num).toDouble(),
                          quantity: itemJson['quantity'] ?? 1,
                        ))
                    .toList() ??
                [],
          );
        }).toList();

        // Sort
        orders.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading orders', e, null, 'OrderHistory');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  // Load chart data
  Future<void> _loadChartData() async {
    try {
      if (!mounted) return;
      setState(() {
        _chartData = [];
        _monthlyChartData = [];
        _yearlyChartData = [];
      });

      final orders = _orders;
      if (orders.isEmpty) return;

      if (_chartPeriod == 'Days') {
        // Get the current week's Monday (start of week)
        final now = DateTime.now();
        final currentWeekday = now.weekday; // Monday = 1, Sunday = 7
        final mondayOfThisWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: currentWeekday - 1));
        final sundayOfThisWeek = mondayOfThisWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

        final dayBuckets = <String, int>{};
        for (final order in orders) {
          // Only count orders from the current week
          if (order.dateTime.isBefore(mondayOfThisWeek) || 
              order.dateTime.isAfter(sundayOfThisWeek)) {
            continue;
          }
          final day = _weekdayLabel(order.dateTime.weekday);
          dayBuckets[day] = (dayBuckets[day] ?? 0) + 1;
        }

        final weekDays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];

        setState(() {
          _chartData = weekDays
              .map((day) => DailyOrderData(
                    day: day,
                    afternoonOrders: dayBuckets[day] ?? 0,
                    nightOrders: 0,
                  ))
              .toList();
        });
        return;
      }

      if (_chartPeriod == 'Months') {
        final currentYear = DateTime.now().year;
        final monthBuckets = <int, int>{};
        for (final order in orders) {
          if (order.dateTime.year != currentYear) continue;
          monthBuckets[order.dateTime.month] =
              (monthBuckets[order.dateTime.month] ?? 0) + 1;
        }

        const monthNames = [
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

        setState(() {
          _monthlyChartData = List.generate(12, (index) {
            final monthIndex = index + 1;
            return MonthlyOrderData(
              month: monthNames[index],
              orders: monthBuckets[monthIndex] ?? 0,
            );
          });
        });
        return;
      }

      final currentYear = DateTime.now().year;
      final yearBuckets = <int, int>{};
      for (final order in orders) {
        yearBuckets[order.dateTime.year] =
            (yearBuckets[order.dateTime.year] ?? 0) + 1;
      }

      setState(() {
        _yearlyChartData = List.generate(5, (index) {
          final year = currentYear - index;
          return YearlyOrderData(
            year: year.toString(),
            orders: yearBuckets[year] ?? 0,
          );
        });
      });
    } catch (e) {
      LoggerService.error('Error loading chart data', e, null, 'OrderHistory');
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  List<HistoricalOrder> _getFilteredOrders() {
    return _orders.where((order) {
      bool filterMatch = true;

      // Apply filter based on filter type
      if (_filterType == 'Day' && _selectedFilterValue.isNotEmpty) {
        // Parse the selected date and compare date portions only (ignore time)
        final selectedDate = DateTime.tryParse(_selectedFilterValue);
        if (selectedDate != null) {
          final orderDate = DateTime(
            order.dateTime.year,
            order.dateTime.month,
            order.dateTime.day,
          );
          final filterDate = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );
          filterMatch = orderDate.isAtSameMomentAs(filterDate);
        } else {
          filterMatch = false;
        }
      } else if (_filterType == 'Month' && _selectedFilterValue.isNotEmpty) {
        // Parse month from selectedFilterValue (e.g., "Jan 2026")
        final parts = _selectedFilterValue.split(' ');
        if (parts.length >= 2) {
          final monthName = parts[0];
          final year = int.tryParse(parts[1]);
          const monthNames = [
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
          final monthIndex = monthNames.indexOf(monthName) + 1;
          filterMatch =
              order.dateTime.month == monthIndex && order.dateTime.year == year;
        }
      } else if (_filterType == 'Year' && _selectedFilterValue.isNotEmpty) {
        final year = int.tryParse(_selectedFilterValue);
        filterMatch = year != null && order.dateTime.year == year;
      }

      // Also apply time filter if not 'All'
      final timeMatch = _selectedTime == 'All' ||
          _getTimeSlot(order.dateTime) == _selectedTime;

      return filterMatch && timeMatch;
    }).toList();
  }

  String _getTimeSlot(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }

  Future<void> _deleteOrder(String id) async {
    // Show confirmation
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Order?',
      message: 'This action cannot be undone. Are you sure?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        String endpoint = '/orders/$id';
        if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
          endpoint += '?location=$_selectedLocation';
        }
        await ApiService.delete(endpoint);

        setState(() {
          _orders.removeWhere((o) => o.id == id);
        });
        if (mounted) {
          Navigator.pop(context); // Close details sheet
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Order deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting order: $e')));
        }
      }
    }
  }

  Future<void> _updateOrderStatus(HistoricalOrder order, String newStatus) async {
    try {
      final body = {
        'status': newStatus,
        'branch': _selectedLocation ?? _userLocation ?? order.location
      };

      await ApiService.patch('/orders/${order.id}', body);
      await _loadOrders();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as ${newStatus.toUpperCase()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating: $e')));
      }
    }
  }

  // Show order details
  void _showOrderDetails(HistoricalOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Order header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order ${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(order.dateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(order.status, isLarge: true),
                  ],
                ),
                if (order.status == 'accepted') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, 'completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark Completed'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, 'failed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B9D),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark Failed'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Admin Delete Action
                if (_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteOrder(order.id),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        label: const Text('Delete Order History',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Location
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFFF7A00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.location,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Order items
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'Qty: ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 32),
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
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
          'Order History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7A00),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFFF7A00),
              onRefresh: () async {
                await _loadOrders();
                await _loadChartData();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Section
                    _buildFilterSection(),
                    const SizedBox(height: 24),
                    // Last Orders Section
                    _buildLastOrdersSection(),
                    const SizedBox(height: 32),
                    // Chart Section
                    _buildChartSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Filter Orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Filter Type Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter By',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _filterType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (value) {
                    setState(() {
                      _filterType = value ?? _filterType;
                      // Reset selected value when filter type changes
                      if (_filterType == 'Day' && _availableDates.isNotEmpty) {
                        _selectedFilterValue = _availableDates.first;
                      } else if (_filterType == 'Month' &&
                          _availableMonths.isNotEmpty) {
                        _selectedFilterValue = _availableMonths.first;
                      } else if (_filterType == 'Year' &&
                          _availableYears.isNotEmpty) {
                        _selectedFilterValue = _availableYears.first;
                      }
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'Day', child: Text('Day')),
                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                    DropdownMenuItem(value: 'Year', child: Text('Year')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Select Value Based on Filter Type
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Select ${_filterType == 'Day' ? 'Date' : _filterType}',
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFilterValue,
                        isExpanded: true,
                        underline: const SizedBox(),
                        onChanged: (value) {
                          setState(() => _selectedFilterValue =
                              value ?? _selectedFilterValue);
                        },
                        items: (_filterType == 'Day'
                                ? _availableDates
                                : _filterType == 'Month'
                                    ? _availableMonths
                                    : _availableYears)
                            .map((val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Time',
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTime,
                        isExpanded: true,
                        underline: const SizedBox(),
                        onChanged: (value) {
                          setState(
                              () => _selectedTime = value ?? _selectedTime);
                        },
                        items: _times.map((time) {
                          return DropdownMenuItem(
                              value: time, child: Text(time));
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastOrdersSection() {
    final filteredOrders = _getFilteredOrders();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtered Orders (${filteredOrders.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No orders found for selected filters',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Column(
              children: filteredOrders.map((order) {
                return GestureDetector(
                  onTap: () => _showOrderDetails(order),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              order.orderNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Builder(
                              builder: (context) {
                                final hour = order.dateTime.hour;
                                final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                                final period = hour >= 12 ? 'PM' : 'AM';
                                return Text(
                                  '$displayHour:${order.dateTime.minute.toString().padLeft(2, '0')} $period',
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              order.location,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Chip(
                              label: Text(
                                order.status,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white),
                              ),
                              backgroundColor: _getStatusChipColor(order.status),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          ),
                          Text(
                            '\$${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isLarge = false}) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'accepted':
        backgroundColor = const Color(0xFF4CAF50).withValues(alpha: 0.2);
        textColor = const Color(0xFF4CAF50);
        label = 'Accepted';
        break;
      case 'completed':
        backgroundColor = const Color(0xFF2E7D32).withValues(alpha: 0.2);
        textColor = const Color(0xFF2E7D32);
        label = 'Completed';
        break;
      case 'rejected':
        backgroundColor = const Color(0xFFFF6B9D).withValues(alpha: 0.2);
        textColor = const Color(0xFFFF6B9D);
        label = 'Rejected';
        break;
      case 'failed':
        backgroundColor = const Color(0xFFD32F2F).withValues(alpha: 0.2);
        textColor = const Color(0xFFD32F2F);
        label = 'Failed';
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 8,
        vertical: isLarge ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isLarge ? 14 : 12,
          fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Color _getStatusChipColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'failed':
        return const Color(0xFFD32F2F);
      case 'accepted':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return const Color(0xFFFF6B9D);
      default:
        return Colors.grey;
    }
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Number of Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                onSelected: (String value) {
                  setState(() {
                    _chartPeriod = value;
                  });
                  _loadChartData();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'Days',
                    child: Text('Days'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Months',
                    child: Text('Months'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Years',
                    child: Text('Years'),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _chartPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 24),
          // Chart
          SizedBox(
            height: 250,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final rows = _getChartRows();
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    const labelWidth = 92.0;
    const valueWidth = 40.0;
    const gap = 8.0;

    final maxOrders = rows
        .map((row) => row.orders)
        .fold<int>(0, (prev, value) => value > prev ? value : prev);
    final safeMax = maxOrders > 0 ? maxOrders : 1;
    final ticks = List<int>.generate(5, (index) {
      final value = (safeMax * index / 4).round();
      return value;
    });

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _chartScrollController,
            thumbVisibility: rows.length > 6,
            child: ListView.builder(
              controller: _chartScrollController,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final barFraction = row.orders / safeMax;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          row.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(
                                height: 12,
                                color: Colors.grey[200],
                              ),
                              FractionallySizedBox(
                                widthFactor: barFraction.isFinite
                                    ? barFraction.clamp(0.0, 1.0)
                                    : 0.0,
                                child: Container(
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF7A00),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: gap),
                      SizedBox(
                        width: valueWidth,
                        child: Text(
                          row.orders.toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(
            left: labelWidth + gap,
            right: valueWidth + gap,
          ),
          child: Row(
            children: ticks.map((tick) {
              return Expanded(
                child: Text(
                  tick.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<_ChartRow> _getChartRows() {
    if (_chartPeriod == 'Days') {
      const weekDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];

      final totalsByDay = <String, int>{};
      for (final item in _chartData) {
        final label = _normalizeDayLabel(item.day);
        final total = item.afternoonOrders + item.nightOrders;
        totalsByDay[label] = (totalsByDay[label] ?? 0) + total;
      }

      return weekDays
          .map((day) => _ChartRow(label: day, orders: totalsByDay[day] ?? 0))
          .toList();
    }

    if (_chartPeriod == 'Months') {
      const monthNames = [
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

      final totalsByMonth = <String, int>{};
      for (final item in _monthlyChartData) {
        final raw = item.month;
        final key = raw.split(' ').first;
        totalsByMonth[key] = (totalsByMonth[key] ?? 0) + item.orders;
      }

      return monthNames
          .map((month) => _ChartRow(label: month, orders: totalsByMonth[month] ?? 0))
          .toList();
    }

    final currentYear = DateTime.now().year;
    final totalsByYear = <String, int>{};
    for (final item in _yearlyChartData) {
      totalsByYear[item.year] = (totalsByYear[item.year] ?? 0) + item.orders;
    }

    return List.generate(5, (index) {
      final year = (currentYear - index).toString();
      return _ChartRow(label: year, orders: totalsByYear[year] ?? 0);
    });
  }

  String _normalizeDayLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('mon')) return 'Monday';
    if (normalized.startsWith('tue')) return 'Tuesday';
    if (normalized.startsWith('wed')) return 'Wednesday';
    if (normalized.startsWith('thu')) return 'Thursday';
    if (normalized.startsWith('fri')) return 'Friday';
    if (normalized.startsWith('sat')) return 'Saturday';
    if (normalized.startsWith('sun')) return 'Sunday';
    return value;
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
                isSelected: true,
                onTap: () {},
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
                    Navigator.pushReplacement(
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
