import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'incoming_orders_screen.dart';
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'sign_in_screen.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/printer_setup_guide_modal.dart';

// Dashboard Models
class DashboardStats {
  final int todayOrders;
  final double todayRevenue;
  final int pendingOrders;
  final int acceptedOrders;
  final int failedOrders;
  final int completedOrders;
  final double revenueChangePercent;
  final double ordersChangePercent;

  DashboardStats({
    required this.todayOrders,
    required this.todayRevenue,
    required this.pendingOrders,
    this.acceptedOrders = 0,
    this.failedOrders = 0,
    required this.completedOrders,
    required this.revenueChangePercent,
    required this.ordersChangePercent,
  });
}

class RecentOrderSummary {
  final String orderNumber;
  final String customerName;
  final double amount;
  final String status;
  final DateTime time;

  RecentOrderSummary({
    required this.orderNumber,
    required this.customerName,
    required this.amount,
    required this.status,
    required this.time,
  });
}

class HourlyOrderData {
  final int hour;
  final int orders;

  HourlyOrderData({
    required this.hour,
    required this.orders,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<RecentOrderSummary> _recentOrders = [];
  List<HourlyOrderData> _hourlyData = [];
  double _hourlyMaxY = 5;
  bool _isLoading = false;

  UserRole? _userRole;
  String? _selectedLocation;
  List<String> _availableLocations = [];
  String? _userName;

  String _normalizeOrderStatus(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'incoming':
      case 'pending':
        return 'incoming';
      case 'accepted':
      case 'inprogress':
      case 'in-progress':
        return 'accepted';
      case 'rejected':
        return 'rejected';
      case 'completed':
        return 'completed';
      case 'failed':
        return 'failed';
      default:
        return 'incoming';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLocationAndData();
  }

  Future<void> _loadLocationAndData() async {
    final authService = AuthService();
    final role = await authService.getUserRole();
    final location = await authService.getUserLocation();
    final name = await authService.getUserName();
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _userRole = role;
      _userName = name;
    });

    if (role == UserRole.staff) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const IncomingOrdersScreen()),
        );
      }
      return;
    }

    if (role == UserRole.admin) {
      // Restore the last dashboard selection (single source of truth)
      final savedLocation = prefs.getString('dashboard_selected_location');
      if (savedLocation != null && savedLocation.isNotEmpty) {
        setState(() {
          _selectedLocation = savedLocation;
        });
      }
      await _fetchLocations();
    } else if (location != null && location.isNotEmpty) {
      setState(() {
        _selectedLocation = location;
      });
    }

    _loadDashboardData();
  }

  Future<void> _fetchLocations() async {
    try {
      final data = await ApiService.get('/branches');
      if (data is Map && data.containsKey('data')) {
        final branches = data['data'] as List;
        final prefs = await SharedPreferences.getInstance();
        final locations = branches.map((b) => b.toString()).toList();
        String? selected = _selectedLocation;
        if (selected != null && !locations.contains(selected)) {
          selected = null;
          await prefs.remove('dashboard_selected_location');
        }
        setState(() {
          _availableLocations = locations;
          _selectedLocation = selected;
        });
      }
    } catch (e) {
      // Error loading locations
    }
  }

  // Load dashboard data from database
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch today's stats from backend (server-side calculation using createdAt)
      String statsEndpoint = '/dashboard/stats';
      if (_userRole == UserRole.admin && _selectedLocation != null) {
        statsEndpoint += '?branch=$_selectedLocation';
      }
      
      // Fetch Orders from backend for recent orders and hourly chart
      String ordersEndpoint = '/orders';
      if (_userRole == UserRole.admin && _selectedLocation != null) {
        ordersEndpoint += '?branch=$_selectedLocation';
      }
      
      // Fetch both in parallel
      final responses = await Future.wait([
        ApiService.get(statsEndpoint),
        ApiService.get(ordersEndpoint),
      ]);
      
      final statsResponse = responses[0];
      final ordersResponse = responses[1];
      
      List<dynamic> ordersList = [];

      // Handle the response format from backend
      if (ordersResponse is Map && ordersResponse.containsKey('data')) {
        ordersList =
            ordersResponse['data'] is List ? ordersResponse['data'] : [];
      } else if (ordersResponse is List) {
        ordersList = ordersResponse;
      }

      if (mounted) {
        setState(() {
          // Use server-side calculated stats
          if (statsResponse is Map && statsResponse['success'] == true && statsResponse['data'] != null) {
            final statsData = statsResponse['data'];
            _stats = DashboardStats(
              todayOrders: (statsData['todayOrders'] as num?)?.toInt() ?? 0,
              todayRevenue: (statsData['todayRevenue'] as num?)?.toDouble() ?? 0.0,
              pendingOrders: (statsData['pendingOrders'] as num?)?.toInt() ?? 0,
              acceptedOrders: (statsData['acceptedOrders'] as num?)?.toInt() ?? 0,
              failedOrders: (statsData['failedOrders'] as num?)?.toInt() ?? 0,
              completedOrders: (statsData['completedOrders'] as num?)?.toInt() ?? 0,
              revenueChangePercent: 0.0,
              ordersChangePercent: 0.0,
            );
          } else {
            _stats = DashboardStats(
              todayOrders: 0,
              todayRevenue: 0.0,
              pendingOrders: 0,
              acceptedOrders: 0,
              failedOrders: 0,
              completedOrders: 0,
              revenueChangePercent: 0.0,
              ordersChangePercent: 0.0,
            );
          }

          // Recent Orders (Take last 5)
          // Sort by date desc first
          ordersList.sort((a, b) {
            final dateStrA = a['createdAt'] ?? a['dateTime'] ?? '';
            final dateStrB = b['createdAt'] ?? b['dateTime'] ?? '';
            final da = (DateTime.tryParse(dateStrA) ?? DateTime.now()).toLocal();
            final db = (DateTime.tryParse(dateStrB) ?? DateTime.now()).toLocal();
            return db.compareTo(da);
          });

          _recentOrders = ordersList.take(5).map((json) {
            double total = 0.0;
            if (json['totalAmount'] != null) {
              total = (json['totalAmount'] as num).toDouble();
            }
            final rawStatus = json['status']?.toString() ?? '';
            final normalizedStatus = _normalizeOrderStatus(rawStatus);
            return RecentOrderSummary(
              orderNumber: json['orderId'] ?? json['orderNumber'] ?? '#',
              customerName: json['customerName'] ?? 'Customer',
              amount: total,
              status: normalizedStatus,
              time: (DateTime.tryParse(
                      json['createdAt'] ?? json['dateTime'] ?? '') ??
                  DateTime.now()).toLocal(),
            );
          }).toList();

          final now = DateTime.now();
          final currentHourStart = DateTime(
            now.year,
            now.month,
            now.day,
            now.hour,
          );
          final startHour = currentHourStart.subtract(const Duration(hours: 5));
          final hourlyBuckets = List<int>.filled(6, 0);

          for (final order in ordersList) {
            final dateStr = order['createdAt'] ?? order['dateTime'] ?? '';
            final orderTime = DateTime.tryParse(dateStr)?.toLocal();
            if (orderTime == null) continue;
            if (orderTime.isBefore(startHour) ||
                orderTime.isAfter(currentHourStart.add(const Duration(hours: 1)))) {
              continue;
            }
            final diffHours = orderTime.difference(startHour).inHours;
            if (diffHours >= 0 && diffHours < 6) {
              hourlyBuckets[diffHours] += 1;
            }
          }

          _hourlyData = List.generate(6, (index) {
            final hour = startHour.add(Duration(hours: index)).hour;
            return HourlyOrderData(hour: hour, orders: hourlyBuckets[index]);
          });

          final maxOrders = hourlyBuckets.isEmpty
              ? 0
              : hourlyBuckets.reduce((a, b) => a > b ? a : b);
          _hourlyMaxY = (maxOrders + 2).toDouble();
          if (_hourlyMaxY < 5) _hourlyMaxY = 5;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
          'Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_userRole == UserRole.admin && _availableLocations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF7A00)),
                ),
                child: DropdownButton<String>(
                  value: _selectedLocation,
                  hint: const Text('Select Branch'),
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFFFF7A00)),
                  underline: const SizedBox(),
                  style: const TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  onChanged: (String? newLocation) async {
                    if (newLocation != null &&
                        newLocation != _selectedLocation) {
                      setState(() {
                        _selectedLocation = newLocation;
                      });
                      // Save selected location for other screens to use
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('dashboard_selected_location', newLocation);
                      _loadDashboardData();
                    }
                  },
                  items: _availableLocations
                      .map<DropdownMenuItem<String>>((String location) {
                    return DropdownMenuItem<String>(
                      value: location,
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Color(0xFFFF7A00)),
                          const SizedBox(width: 4),
                          Text(location),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.black),
                if (_stats != null && _stats!.pendingOrders > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B9D),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_stats!.pendingOrders}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IncomingOrdersScreen(),
                ),
              );
            },
          ),
        ],
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
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),
                    // Stats Cards
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    // Hourly Orders Chart
                    _buildHourlyOrdersChart(),
                    const SizedBox(height: 24),
                    // Order Status Overview
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildOrderStatusChart()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildQuickActions()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Recent Orders
                    _buildRecentOrders(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFF9933)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName != null && _userName!.isNotEmpty
                      ? _userName!
                      : 'SpiceHut Admin',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (_stats != null)
                  Text(
                    '${_stats!.todayOrders} orders today',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Today Revenue (Online)',
              value: '\$${_stats!.todayRevenue.toStringAsFixed(2)}',
              change: _stats!.revenueChangePercent,
              icon: Icons.attach_money,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Pending Orders (Online)',
              value: '${_stats!.pendingOrders}',
              icon: Icons.pending_actions,
              color: const Color(0xFFFF9800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    double? change,
    required IconData icon,
    required Color color,
  }) {
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  change >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: change >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF6B9D),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${change.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: change >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF6B9D),
                  ),
                ),
                Text(
                  ' vs yesterday',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHourlyOrdersChart() {
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
            'Orders Today (Online)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hourly breakdown',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _hourlyData.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _hourlyMaxY,
                      minY: 0,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${rod.toY.toInt()} orders',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _hourlyData.length) {
                                final hour = _hourlyData[index].hour;
                                final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                                final period = hour >= 12 ? 'PM' : 'AM';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '$displayHour$period',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _hourlyData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.orders.toDouble(),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A00), Color(0xFFFF9933)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    if (_stats == null) return const SizedBox();

    final failed = (_stats?.failedOrders ?? 0).toDouble();
    final completed = (_stats?.completedOrders ?? 0).toDouble();
    final total = failed + completed;

    // Calculate percentages safely (handle division by zero)
    final completedPercent = total > 0 ? ((completed / total) * 100).toInt() : 0;
    final failedPercent = total > 0 ? ((failed / total) * 100).toInt() : 0;

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
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: total > 0
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: [
                        PieChartSectionData(
                          value: completed,
                          title: '$completedPercent%',
                          color: const Color(0xFFFF9800),
                          radius: 35,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: failed,
                          title: '$failedPercent%',
                          color: const Color(0xFFD32F2F),
                          radius: 35,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Text(
                      'No orders yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
            _buildLegendItem(
              'Completed', const Color(0xFFFF9800), completed.isFinite ? completed.toInt() : 0),
          const SizedBox(height: 8),
            _buildLegendItem('Failed', const Color(0xFFD32F2F), failed.isFinite ? failed.toInt() : 0),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'View Orders',
            Icons.shopping_bag_outlined,
            const Color(0xFFFF7A00),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IncomingOrdersScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Analytics',
            Icons.analytics_outlined,
            const Color(0xFF2196F3),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Order History',
            Icons.history,
            const Color(0xFF9C27B0),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'In-House Tables',
            Icons.table_restaurant,
            const Color(0xFFE91E63),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InHouseOrdersScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_userRole == UserRole.admin || _userRole == UserRole.manager) ...[
            _buildActionButton(
              'Edit Void Code',
              Icons.shield_outlined,
              const Color(0xFFFF5722),
              _showVoidCodeDialog,
            ),
            const SizedBox(height: 12),
          ],
          if (_userRole == UserRole.admin) ...[
            _buildActionButton(
              'Menu Management',
              Icons.menu_book,
              const Color(0xFF009688),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MenuManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'User Management',
              Icons.people,
              const Color(0xFF607D8B),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  void _showVoidCodeDialog() async {
    final voidCodeController = TextEditingController();
    String? currentVoidCode;
    bool isLoading = true;

    // Fetch current void code
    try {
      final response = await ApiService.get(
        '/void-codes?location=$_selectedLocation',
      );
      if (response['success'] == true) {
        currentVoidCode = response['data']['voidCode'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading void code: $e')),
        );
      }
    }

    if (!mounted) return;

    await DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          if (isLoading && currentVoidCode != null) {
            voidCodeController.text = currentVoidCode;
            isLoading = false;
          }

          return AlertDialog(
            title: Text('Edit Void Code - $_selectedLocation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Code: ${currentVoidCode ?? 'Loading...'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: voidCodeController,
                  decoration: const InputDecoration(
                    labelText: 'New Void Code',
                    hintText: 'Enter at least 4 characters',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 20,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This code is required to remove items from saved orders.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newCode = voidCodeController.text.trim();
                  if (newCode.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Void code must be at least 4 characters'),
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await ApiService.patch('/void-codes', {
                      'location': _selectedLocation,
                      'voidCode': newCode,
                    });

                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Void code updated to: $newCode'),
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentOrders() {
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
              const Text(
                'Recent Orders (Online)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFFFF7A00),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No recent orders',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            )
          else
            ..._recentOrders.map((order) => _buildRecentOrderItem(order)),
        ],
      ),
    );
  }

  Widget _buildRecentOrderItem(RecentOrderSummary order) {
    Color statusColor;
    Color statusBgColor;
    String statusText;

    switch (order.status) {
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusBgColor = const Color(0xFF4CAF50).withValues(alpha: 0.1);
        statusText = 'Completed';
        break;
      case 'incoming':
        statusColor = const Color(0xFFFF9800);
        statusBgColor = const Color(0xFFFF9800).withValues(alpha: 0.1);
        statusText = 'Incoming';
        break;
      case 'accepted':
        statusColor = const Color(0xFF4CAF50);
        statusBgColor = const Color(0xFF4CAF50).withValues(alpha: 0.1);
        statusText = 'Accepted';
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF6B9D);
        statusBgColor = const Color(0xFFFF6B9D).withValues(alpha: 0.1);
        statusText = 'Rejected';
        break;
      case 'failed':
        statusColor = const Color(0xFFD32F2F);
        statusBgColor = const Color(0xFFD32F2F).withValues(alpha: 0.1);
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.withValues(alpha: 0.1);
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '\$${order.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
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
              _buildMenuItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                isSelected: true,
                onTap: () {
                  Navigator.pop(context);
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
                  Navigator.push(
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
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
              ),
              _buildMenuItem(
                icon: Icons.phone_in_talk,
                label: 'On Call Orders',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OnCallOrdersScreen(),
                    ),
                  );
                },
              ),
              if (_userRole == UserRole.admin)
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
              if (_userRole == UserRole.admin)
                _buildMenuItem(
                  icon: Icons.people,
                  label: 'User Management',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
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
}
