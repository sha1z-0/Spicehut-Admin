import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'incoming_orders_screen.dart';
import 'order_history_screen.dart';
import 'dashboard_screen.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import 'sign_in_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/analytics_report_service.dart';
import '../services/printer_service.dart';
import '../widgets/printer_setup_guide_modal.dart';

// Analytics Models
class IncomeData {
  final double todayIncome;
  final double monthIncome;

  IncomeData({
    required this.todayIncome,
    required this.monthIncome,
  });
}

class UserVoidCount {
  final String user;
  final int count;

  UserVoidCount({
    required this.user,
    required this.count,
  });
}

class InHouseOrdersData {
  final int todayOrders;
  final int monthOrders;
  final double todayRevenue;
  final double monthRevenue;
  final double todayCash;
  final double monthCash;
  final double todayCard;
  final double monthCard;
  final int todayVoided;
  final int monthVoided;
  final List<UserVoidCount> todayVoidedByUser;
  final List<UserVoidCount> monthVoidedByUser;
  final double todayTips;
  final double monthTips;
  final double todayCashTips;
  final double monthCashTips;
  final double todayCardTips;
  final double monthCardTips;
  final int todayOnCallTakeaway;
  final int monthOnCallTakeaway;
  final int todayOnCallDelivery;
  final int monthOnCallDelivery;
  final double todayOnCallTakeawayRevenue;
  final double monthOnCallTakeawayRevenue;
  final double todayOnCallDeliveryRevenue;
  final double monthOnCallDeliveryRevenue;

  InHouseOrdersData({
    required this.todayOrders,
    required this.monthOrders,
    required this.todayRevenue,
    required this.monthRevenue,
    required this.todayCash,
    required this.monthCash,
    required this.todayCard,
    required this.monthCard,
    required this.todayVoided,
    required this.monthVoided,
    required this.todayVoidedByUser,
    required this.monthVoidedByUser,
    required this.todayTips,
    required this.monthTips,
    required this.todayCashTips,
    required this.monthCashTips,
    required this.todayCardTips,
    required this.monthCardTips,
    required this.todayOnCallTakeaway,
    required this.monthOnCallTakeaway,
    required this.todayOnCallDelivery,
    required this.monthOnCallDelivery,
    required this.todayOnCallTakeawayRevenue,
    required this.monthOnCallTakeawayRevenue,
    required this.todayOnCallDeliveryRevenue,
    required this.monthOnCallDeliveryRevenue,
  });
}

class TopSellingItem {
  final int rank;
  final String name;
  final int quantity;
  final String? imageUrl;

  TopSellingItem({
    required this.rank,
    required this.name,
    required this.quantity,
    this.imageUrl,
  });
}

class ChartPoint {
  final String label;
  final double income;

  ChartPoint({
    required this.label,
    required this.income,
  });
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  IncomeData? _incomeData;
  InHouseOrdersData? _inHouseData;
  List<TopSellingItem> _topItems = [];
  List<TopSellingItem> _topInHouseItems = [];
  List<ChartPoint> _chartData = [];
  bool _isLoading = false;
  String _selectedPeriod = 'Month'; // Days, Month, Year
  bool _isAdmin = false;
  UserRole? _userRole;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  String? _userLocation;

  Future<void> _loadLocationAndAnalytics() async {
    if (_userRole == UserRole.staff) return;
    final authService = AuthService();
    final prefs = await SharedPreferences.getInstance();
    _userLocation = await authService.getUserLocation();

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
    
    _loadAnalytics();
  }

  Future<void> _checkRole() async {
    final role = await AuthService().getUserRole();
    setState(() {
      _isAdmin = role == UserRole.admin;
      _userRole = role;
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

    _loadLocationAndAnalytics();
  }

  // Load analytics data from database
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
        final periodParam = _selectedPeriod == 'Days'
          ? 'week'
          : _selectedPeriod.toLowerCase();
        String endpoint = '/analytics?period=$periodParam';
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        endpoint += '&branch=$_selectedLocation';
      }

      // Fetch both online and in-house analytics in parallel
      final responses = await Future.wait([
        ApiService.get(endpoint),
        if (_selectedLocation != null && _selectedLocation!.isNotEmpty)
          ApiService.get('/analytics/inhouse?branch=$_selectedLocation')
        else
          Future.value({})
      ]);

      final response = responses[0];
      final inhouseResponse = responses.length > 1 ? responses[1] : {};

        final rawData = (response is Map && response['data'] != null)
          ? response['data']
          : response;
        final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

        final rawInHouseData = (inhouseResponse is Map && inhouseResponse['data'] != null)
          ? inhouseResponse['data']
          : <String, dynamic>{};
      
      if (mounted) {
        setState(() {
          _incomeData = IncomeData(
            todayIncome: (data['todayIncome'] as num?)?.toDouble() ?? 0.0,
            monthIncome: (data['monthIncome'] as num?)?.toDouble() ?? 0.0,
          );

          _inHouseData = InHouseOrdersData(
            todayOrders: (rawInHouseData['todayOrders'] as num?)?.toInt() ?? 0,
            monthOrders: (rawInHouseData['monthOrders'] as num?)?.toInt() ?? 0,
            todayRevenue: (rawInHouseData['todayRevenue'] as num?)?.toDouble() ?? 0.0,
            monthRevenue: (rawInHouseData['monthRevenue'] as num?)?.toDouble() ?? 0.0,
            todayCash: (rawInHouseData['todayCash'] as num?)?.toDouble() ?? 0.0,
            monthCash: (rawInHouseData['monthCash'] as num?)?.toDouble() ?? 0.0,
            todayCard: (rawInHouseData['todayCard'] as num?)?.toDouble() ?? 0.0,
            monthCard: (rawInHouseData['monthCard'] as num?)?.toDouble() ?? 0.0,
            todayVoided: (rawInHouseData['todayVoided'] as num?)?.toInt() ?? 0,
            monthVoided: (rawInHouseData['monthVoided'] as num?)?.toInt() ?? 0,
            todayVoidedByUser: ((rawInHouseData['todayVoidedByUser'] as List?) ?? [])
                .map((e) {
                  final row = (e as Map).cast<String, dynamic>();
                  return UserVoidCount(
                    user: (row['user'] as String?) ?? 'Unknown',
                    count: (row['count'] as num?)?.toInt() ?? 0,
                  );
                })
                .toList(),
            monthVoidedByUser: ((rawInHouseData['monthVoidedByUser'] as List?) ?? [])
                .map((e) {
                  final row = (e as Map).cast<String, dynamic>();
                  return UserVoidCount(
                    user: (row['user'] as String?) ?? 'Unknown',
                    count: (row['count'] as num?)?.toInt() ?? 0,
                  );
                })
                .toList(),
            todayTips: (rawInHouseData['todayTips'] as num?)?.toDouble() ?? 0.0,
            monthTips: (rawInHouseData['monthTips'] as num?)?.toDouble() ?? 0.0,
            todayCashTips: (rawInHouseData['todayCashTips'] as num?)?.toDouble() ?? 0.0,
            monthCashTips: (rawInHouseData['monthCashTips'] as num?)?.toDouble() ?? 0.0,
            todayCardTips: (rawInHouseData['todayCardTips'] as num?)?.toDouble() ?? 0.0,
            monthCardTips: (rawInHouseData['monthCardTips'] as num?)?.toDouble() ?? 0.0,
            todayOnCallTakeaway: (rawInHouseData['todayOnCallTakeaway'] as num?)?.toInt() ?? 0,
            monthOnCallTakeaway: (rawInHouseData['monthOnCallTakeaway'] as num?)?.toInt() ?? 0,
            todayOnCallDelivery: (rawInHouseData['todayOnCallDelivery'] as num?)?.toInt() ?? 0,
            monthOnCallDelivery: (rawInHouseData['monthOnCallDelivery'] as num?)?.toInt() ?? 0,
            todayOnCallTakeawayRevenue: (rawInHouseData['todayOnCallTakeawayRevenue'] as num?)?.toDouble() ?? 0.0,
            monthOnCallTakeawayRevenue: (rawInHouseData['monthOnCallTakeawayRevenue'] as num?)?.toDouble() ?? 0.0,
            todayOnCallDeliveryRevenue: (rawInHouseData['todayOnCallDeliveryRevenue'] as num?)?.toDouble() ?? 0.0,
            monthOnCallDeliveryRevenue: (rawInHouseData['monthOnCallDeliveryRevenue'] as num?)?.toDouble() ?? 0.0,
          );

          final topItems = (data['topItems'] as List?) ?? [];
          _topItems = topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return TopSellingItem(
              rank: (item['rank'] as num?)?.toInt() ?? (index + 1),
              name: item['name'] ?? 'Unknown',
              quantity: (item['quantity'] as num?)?.toInt() ?? 0,
            );
          }).toList();

          final topInHouseItems = (rawInHouseData['topItems'] as List?) ?? [];
          _topInHouseItems = topInHouseItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return TopSellingItem(
              rank: (item['rank'] as num?)?.toInt() ?? (index + 1),
              name: item['name'] ?? 'Unknown',
              quantity: (item['quantity'] as num?)?.toInt() ?? 0,
            );
          }).toList();

          final chartData = (data['chartData'] as List?) ?? [];
          _chartData = _buildChartData(chartData, data);

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _incomeData = null;
          _inHouseData = null;
          _topItems = [];
          _topInHouseItems = [];
          _chartData = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  List<ChartPoint> _buildChartData(List<dynamic> rawData, Map data) {
    final now = DateTime.now();

    if (_selectedPeriod == 'Days') {
      final startString = data['weekStart']?.toString();
      final start = (DateTime.tryParse(startString ?? '') ??
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6))).toLocal();
      final incomeByDate = <String, double>{};
      for (final item in rawData) {
        final raw = item as Map<String, dynamic>;
        final date = raw['date'] as String?;
        if (date == null || date.isEmpty) continue;
        incomeByDate[date] = (raw['income'] as num?)?.toDouble() ?? 0.0;
      }

      return List.generate(7, (index) {
        final day = start.add(Duration(days: index));
        final key = _dateKey(day);
        return ChartPoint(
          label: day.day.toString(),
          income: incomeByDate[key] ?? 0.0,
        );
      });
    }

    if (_selectedPeriod == 'Month') {
      final incomeByMonth = <int, double>{};
      for (final item in rawData) {
        final raw = item as Map<String, dynamic>;
        final month = (raw['month'] as num?)?.toInt();
        if (month == null) continue;
        incomeByMonth[month] = (raw['income'] as num?)?.toDouble() ?? 0.0;
      }

      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return List.generate(12, (index) {
        final monthIndex = index + 1;
        return ChartPoint(
          label: months[index],
          income: incomeByMonth[monthIndex] ?? 0.0,
        );
      });
    }

    if (_selectedPeriod == 'Year') {
      final incomeByYear = <int, double>{};
      for (final item in rawData) {
        final raw = item as Map<String, dynamic>;
        final year = (raw['year'] as num?)?.toInt();
        if (year == null) continue;
        incomeByYear[year] = (raw['income'] as num?)?.toDouble() ?? 0.0;
      }

      return List.generate(5, (index) {
        final year = now.year - 4 + index;
        return ChartPoint(
          label: year.toString(),
          income: incomeByYear[year] ?? 0.0,
        );
      });
    }

    return [];
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _monthShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadAnalytics();
  }

  Future<void> _printAnalyticsReport() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating analytics report...')),
    );

    try {
      final response = await ApiService.get(
        '/analytics/report?branch=$_selectedLocation',
      );
      final data = (response is Map && response['data'] != null)
          ? response['data']
          : response;

      await AnalyticsReportService.generateAndPrintReport(
        branchName: _selectedLocation!,
        data: data,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  Future<bool> _ensurePrinterConnected() async {
    final hasBillPrinter = await PrinterService.hasBillPrinterConfigured(
      branchId: _selectedLocation,
    );

    if (!mounted) return false;

    if (hasBillPrinter) {
      return true;
    }

    if (mounted) {
      await DialogUtils.showAnimatedDialog(
        context: context,
        builder: (_) => const PrinterSetupGuideModal(),
      );

      if (!mounted) return false;

      final configuredAfterSetup = await PrinterService.hasBillPrinterConfigured(
        branchId: _selectedLocation,
      );

      if (!mounted) return false;

      if (configuredAfterSetup) {
        return true;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printer not configured. Please set up a printer.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return false;
  }

  Future<void> _generateAnalyticsSlip() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) return;
    if (_inHouseData == null || _incomeData == null) return;
    if (!await _ensurePrinterConnected()) return;

    try {
      final now = DateTime.now();
      final slip = <String>[];

      slip.add('═════════════════════════════════════════');
      slip.add('           ANALYTICS REPORT');
      slip.add('─────────────────────────────────────────');
      slip.add('Branch: $_selectedLocation');
      slip.add('Date: ${now.day}/${now.month}/${now.year}');
      slip.add('Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      slip.add('═════════════════════════════════════════\n');

      // Online Orders
      slip.add('ONLINE ORDERS');
      slip.add('─────────────────────────────────────────');
      slip.add("Today's Revenue:     \$${_incomeData!.todayIncome.toStringAsFixed(2)}");
      slip.add("Month's Revenue:     \$${_incomeData!.monthIncome.toStringAsFixed(2)}");
      slip.add('\n');

      // In-House Orders
      slip.add('IN-HOUSE ORDERS');
      slip.add('─────────────────────────────────────────');
      slip.add('Orders Today:        ${_inHouseData!.todayOrders}');
      slip.add('Orders This Month:   ${_inHouseData!.monthOrders}');
      slip.add('Revenue Today:       \$${_inHouseData!.todayRevenue.toStringAsFixed(2)}');
      slip.add('Revenue This Month:  \$${_inHouseData!.monthRevenue.toStringAsFixed(2)}');
      slip.add('\n');

      // Payment Methods
      slip.add('PAYMENT METHODS (IN-HOUSE)');
      slip.add('─────────────────────────────────────────');
      slip.add('CASH');
      slip.add('  Today:             \$${_inHouseData!.todayCash.toStringAsFixed(2)}');
      slip.add('  Month:             \$${_inHouseData!.monthCash.toStringAsFixed(2)}');
      slip.add('CARD');
      slip.add('  Today:             \$${_inHouseData!.todayCard.toStringAsFixed(2)}');
      slip.add('  Month:             \$${_inHouseData!.monthCard.toStringAsFixed(2)}');
      slip.add('\n');

      // Voided Orders
      slip.add('VOIDED ORDERS (IN-HOUSE)');
      slip.add('─────────────────────────────────────────');
      slip.add('Voided Today:        ${_inHouseData!.todayVoided}');
      slip.add('Voided This Month:   ${_inHouseData!.monthVoided}');
      
      if (_inHouseData!.todayVoidedByUser.isNotEmpty) {
        slip.add('\nVoided By User (Today):');
        for (final userVoid in _inHouseData!.todayVoidedByUser) {
          slip.add('  ${userVoid.user}: ${userVoid.count}');
        }
      }
      
      if (_inHouseData!.monthVoidedByUser.isNotEmpty) {
        slip.add('\nVoided By User (Month):');
        for (final userVoid in _inHouseData!.monthVoidedByUser) {
          slip.add('  ${userVoid.user}: ${userVoid.count}');
        }
      }
      slip.add('\n');

      // Tips
      slip.add('TIPS (IN-HOUSE)');
      slip.add('─────────────────────────────────────────');
      slip.add('Total Tips Today:    \$${_inHouseData!.todayTips.toStringAsFixed(2)}');
      slip.add('Total Tips Month:    \$${_inHouseData!.monthTips.toStringAsFixed(2)}');
      slip.add('\nBy Payment Method:');
      slip.add('  Cash Tips Today:   \$${_inHouseData!.todayCashTips.toStringAsFixed(2)}');
      slip.add('  Cash Tips Month:   \$${_inHouseData!.monthCashTips.toStringAsFixed(2)}');
      slip.add('  Card Tips Today:   \$${_inHouseData!.todayCardTips.toStringAsFixed(2)}');
      slip.add('  Card Tips Month:   \$${_inHouseData!.monthCardTips.toStringAsFixed(2)}');
      slip.add('\n');

      // On-Call Orders
      slip.add('ON-CALL ORDERS');
      slip.add('─────────────────────────────────────────');
      slip.add('TAKEAWAY');
      slip.add('  Orders Today:      ${_inHouseData!.todayOnCallTakeaway}');
      slip.add('  Orders Month:      ${_inHouseData!.monthOnCallTakeaway}');
      slip.add('  Revenue Today:     \$${_inHouseData!.todayOnCallTakeawayRevenue.toStringAsFixed(2)}');
      slip.add('  Revenue Month:     \$${_inHouseData!.monthOnCallTakeawayRevenue.toStringAsFixed(2)}');
      slip.add('\nDELIVERY');
      slip.add('  Orders Today:      ${_inHouseData!.todayOnCallDelivery}');
      slip.add('  Orders Month:      ${_inHouseData!.monthOnCallDelivery}');
      slip.add('  Revenue Today:     \$${_inHouseData!.todayOnCallDeliveryRevenue.toStringAsFixed(2)}');
      slip.add('  Revenue Month:     \$${_inHouseData!.monthOnCallDeliveryRevenue.toStringAsFixed(2)}');
      slip.add('\n');

      slip.add('═════════════════════════════════════════');
      slip.add('Generated on ${DateTime.now().toString().split('.')[0]}');
      slip.add('═════════════════════════════════════════\n\n\n');

      await PrinterService.printAnalyticsSlip(
        slip,
        branchId: _selectedLocation,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics slip printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating slip: $e')),
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
          'Analytics',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isAdmin) ...[
            TextButton.icon(
              onPressed: _generateAnalyticsSlip,
              icon: const Icon(Icons.receipt_long, color: Colors.green),
              label: const Text(
                'Generate Slip',
                style: TextStyle(color: Colors.green),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _printAnalyticsReport,
              icon: const Icon(Icons.print, color: Colors.blue),
              label: const Text(
                'Print Report',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
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
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Online Orders Section
                    const Text(
                      'Online Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Income Cards Row
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildPerDayIncomeCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildTotalIncomeCard()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTopSellingCard(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Income Chart
                    _buildIncomeChart(),
                    const SizedBox(height: 32),

                    // In-House Orders Section
                    const Text(
                      'In-House Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // In-House Orders Cards
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildInHouseOrdersTodayCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildInHouseOrdersMonthCard()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildInHouseRevenueTodayCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildInHouseRevenueMonthCard()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Methods Section
                    const Text(
                      'Payment Methods (In-House)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildCashPaymentsCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCardPaymentsCard()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Voided & Tips Section
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildVoidedOrdersCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTipsCard()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Voided By User Section
                    const Text(
                      'Orders Voided by User (In-House)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVoidedByUserCard(),
                    const SizedBox(height: 24),

                    // Tips by Payment Method Section
                    const Text(
                      'Tips by Payment Method (In-House)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildCashTipsCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCardTipsCard()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // On-Call Takeaway Orders Section
                    const Text(
                      'On-Call Takeaway Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildOnCallTakeawayTodayOrdersCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildOnCallTakeawayMonthOrdersCard()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildOnCallTakeawayTodayRevenueCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildOnCallTakeawayMonthRevenueCard()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // On-Call Delivery Orders Section
                    const Text(
                      'On-Call Delivery Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildOnCallDeliveryTodayOrdersCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildOnCallDeliveryMonthOrdersCard()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(child: _buildOnCallDeliveryTodayRevenueCard()),
                                const SizedBox(height: 16),
                                Expanded(child: _buildOnCallDeliveryMonthRevenueCard()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Top In-House Items
                    _buildTopInHouseItemsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPerDayIncomeCard() {
    if (_incomeData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Revenue",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_incomeData!.todayIncome.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.attach_money,
              color: Color(0xFFFF7A00),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingCard() {
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
            'Top Ordered Items (Online)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed orders only',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (_topItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No completed orders yet',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            ...(_topItems.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                        ),
                        child: Text(
                          '#${item.rank}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7A00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ))),
        ],
      ),
    );
  }

  Widget _buildTotalIncomeCard() {
    if (_incomeData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Month's Revenue",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_incomeData!.monthIncome.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.attach_money,
              color: Color(0xFFFF7A00),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeChart() {
    final maxIncome = _chartData.fold<double>(0, (prev, item) => item.income > prev ? item.income : prev);
    final safeMax = maxIncome > 0 ? maxIncome : 1;
    final maxY = safeMax * 1.2;
    final interval = maxY / 4;

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
          // Header with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPeriod == 'Days'
                  ? 'Income (Days - ${_monthShort(DateTime.now())})'
                  : 'Income ($_selectedPeriod)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                onSelected: _changePeriod,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Days', child: Text('Days')),
                  PopupMenuItem(value: 'Month', child: Text('Month')),
                  PopupMenuItem(value: 'Year', child: Text('Year')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedPeriod,
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
          const SizedBox(height: 24),
          // Chart
          SizedBox(
            height: 250,
            child: _chartData.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            interval: 1, // Always show every data point
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _chartData.length) {
                                String label = _chartData[value.toInt()].label;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    label,
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
                            reservedSize: 45,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatYAxisValue(value),
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
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (_chartData.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartData.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value.income,
                            );
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFFFF7A00),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: const Color(0xFFFF7A00),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFE5D3).withValues(alpha: 0.5),
                                const Color(0xFFFFE5D3).withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          getTooltipColor: (touchedSpot) => const Color(0xFFFF7A00),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              final index = touchedSpot.x.toInt();
                              final period = index >= 0 && index < _chartData.length 
                                  ? _chartData[index].label 
                                  : '';
                              final income = touchedSpot.y;
                              return LineTooltipItem(
                                '$period\n\$${income.toStringAsFixed(2)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              );
                            }).toList();
                          },
                        ),
                        handleBuiltInTouches: true,
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: const Color(0xFFFF7A00).withValues(alpha: 0.5),
                                strokeWidth: 2,
                                dashArray: [5, 5],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: const Color(0xFFFF7A00),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
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
                isSelected: true,
                onTap: () {},
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
                    builder: (context) =>
                        const PrinterSetupGuideModal(),
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

  Widget _buildInHouseOrdersTodayCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'In-House Orders',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.todayOrders}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart,
              color: Colors.blue[600],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInHouseOrdersMonthCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'In-House Orders',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.monthOrders}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month,
              color: Colors.blue[600],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInHouseRevenueTodayCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'In-House Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.todayRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.attach_money,
              color: Colors.green[600],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInHouseRevenueMonthCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'In-House Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.monthRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month,
              color: Colors.green[600],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashPaymentsCard() {
    if (_inHouseData == null) return const SizedBox();

    return Column(
      children: [
        Expanded(
          child: Container(
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.payments,
                        color: Colors.orange[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cash Payments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Today: \$${_inHouseData!.todayCash.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Month: \$${_inHouseData!.monthCash.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardPaymentsCard() {
    if (_inHouseData == null) return const SizedBox();

    return Column(
      children: [
        Expanded(
          child: Container(
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.credit_card,
                        color: Colors.purple[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Card Payments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Today: \$${_inHouseData!.todayCard.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Month: \$${_inHouseData!.monthCard.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoidedOrdersCard() {
    if (_inHouseData == null) return const SizedBox();

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.block,
                  color: Colors.red[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Voided Orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Today: ${_inHouseData!.todayVoided}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Month: ${_inHouseData!.monthVoided}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    if (_inHouseData == null) return const SizedBox();

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: Colors.amber[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total Tips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Today: \$${_inHouseData!.todayTips.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Month: \$${_inHouseData!.monthTips.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashTipsCard() {
    if (_inHouseData == null) return const SizedBox();

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: Colors.green[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cash Tips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Today: \$${_inHouseData!.todayCashTips.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Month: \$${_inHouseData!.monthCashTips.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTipsCard() {
    if (_inHouseData == null) return const SizedBox();

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.credit_card,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Card Tips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Today: \$${_inHouseData!.todayCardTips.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Month: \$${_inHouseData!.monthCardTips.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallTakeawayTodayOrdersCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'On-Call Takeaway',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.todayOnCallTakeaway}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: Colors.orange[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallTakeawayMonthOrdersCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'On-Call Takeaway',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.monthOnCallTakeaway}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Colors.orange[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallTakeawayTodayRevenueCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Takeaway Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.todayOnCallTakeawayRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.attach_money,
              color: Colors.orange[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallTakeawayMonthRevenueCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Takeaway Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.monthOnCallTakeawayRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.attach_money,
              color: Colors.orange[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallDeliveryTodayOrdersCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'On-Call Delivery',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.todayOnCallDelivery}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delivery_dining,
              color: Colors.green[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallDeliveryMonthOrdersCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'On-Call Delivery',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_inHouseData!.monthOnCallDelivery}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Colors.green[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallDeliveryTodayRevenueCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Delivery Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.todayOnCallDeliveryRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.attach_money,
              color: Colors.green[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnCallDeliveryMonthRevenueCard() {
    if (_inHouseData == null) return const SizedBox();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Delivery Revenue',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_inHouseData!.monthOnCallDeliveryRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.attach_money,
              color: Colors.green[700],
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoidedByUserCard() {
    if (_inHouseData == null) return const SizedBox();

    final monthList = _inHouseData!.monthVoidedByUser;
    final todayMap = {
      for (final row in _inHouseData!.todayVoidedByUser) row.user: row.count
    };

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.red[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Voided Orders by User',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (monthList.isEmpty)
            Text(
              'No voided orders yet',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          else
            ...monthList.take(8).map(
              (row) {
                final todayCount = todayMap[row.user] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                        ),
                      ),
                      Text(
                        'Today: $todayCount',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Month: ${row.count}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopInHouseItemsCard() {
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
            'Top In-House Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Most ordered items in-house',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (_topInHouseItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No in-house orders yet',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            ...(_topInHouseItems.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                        ),
                        child: Text(
                          '#${item.rank}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7A00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                )))
            .toList(),
        ],
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
