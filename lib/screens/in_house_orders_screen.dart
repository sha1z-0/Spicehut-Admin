import 'dart:math';
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
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import 'user_management_screen.dart';
import 'incoming_orders_screen.dart';
import 'sign_in_screen.dart';
import '../widgets/printer_setup_guide_modal.dart';
import '../widgets/printer_status_chip.dart';
import '../widgets/spice_level_picker_dialog.dart';

// ============================================================================
// EXTENSIONS
// ============================================================================

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

// ============================================================================
// DATA MODELS
// ============================================================================

enum TableStatus { available, occupied, awaitingBill, reserved, closed }

// ignore: constant_identifier_names
enum SectionType { main_hall, outdoor, vip_room, private_dining }

enum TableShape { circle, square, rectangle }

class RestaurantTable {
  final String id;
  String name; // e.g., "T1", "Table 12"
  int number;
  int capacity;
  TableStatus status;
  double posX;
  double posY;
  double width;
  double height;
  double rotation; // 0-360 degrees
  TableShape shape;
  final String sectionId;
  List<OrderItem> currentOrder;
  String? currentOrderToken;
  String? assignedWaiter;
  double? billTotal;
  DateTime? lastModified;

  RestaurantTable({
    required this.id,
    required this.name,
    required this.number,
    required this.capacity,
    this.status = TableStatus.available,
    required this.posX,
    required this.posY,
    this.width = 60,
    this.height = 60,
    this.rotation = 0,
    this.shape = TableShape.circle,
    required this.sectionId,
    List<OrderItem>? currentOrder,
    this.currentOrderToken,
    this.assignedWaiter,
    this.billTotal,
    this.lastModified,
  }) : currentOrder = currentOrder ?? [];

  Color get statusColor {
    switch (status) {
      case TableStatus.available:
        return Colors.green;
      case TableStatus.occupied:
      case TableStatus.awaitingBill:
        return Colors.red;
      case TableStatus.reserved:
        return Colors.blue;
      case TableStatus.closed:
        return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
      case TableStatus.awaitingBill:
        return 'Occupied';
      case TableStatus.reserved:
        return 'Reserved';
      case TableStatus.closed:
        return 'Closed';
    }
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'number': number,
        'capacity': capacity,
        'status': status.toString().split('.').last,
        'posX': posX,
        'posY': posY,
        'width': width,
        'height': height,
        'rotation': rotation,
        'shape': shape.toString().split('.').last,
        'sectionId': sectionId,
        'currentOrder': currentOrder.map((e) => e.toJson()).toList(),
        'currentOrderToken': currentOrderToken,
        'assignedWaiter': assignedWaiter,
        'billTotal': billTotal,
      };
}

class OrderItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String category;
  final String? imageUrl;
  final String? spiceLevel;
  final bool isAlcohol;
  DateTime addedAt;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    required this.category,
    this.imageUrl,
    this.spiceLevel,
    this.isAlcohol = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  double get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'category': category,
        'imageUrl': imageUrl,
        'spiceLevel': spiceLevel,
        'isAlcohol': isAlcohol,
      };
}

class TableSection {
  final String id;
  final String name;
  final SectionType type;
  final List<RestaurantTable> tables;
  final double sectionWidth;
  final double sectionHeight;

  TableSection({
    required this.id,
    required this.name,
    required this.type,
    List<RestaurantTable>? tables,
    this.sectionWidth = 1200, // Optimized for iPad (4:3 aspect ratio)
    this.sectionHeight = 900,
  }) : tables = tables ?? [];
}

class RestaurantFloorPlan {
  final String id;
  final String branchId;
  final String branchName;
  final List<TableSection> sections;
  final bool isEditMode;
  DateTime lastSynced;

  RestaurantFloorPlan({
    required this.id,
    required this.branchId,
    required this.branchName,
    List<TableSection>? sections,
    this.isEditMode = false,
    DateTime? lastSynced,
  })  : sections = sections ?? [],
        lastSynced = lastSynced ?? DateTime.now();
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class InHouseOrdersScreen extends StatefulWidget {
  const InHouseOrdersScreen({super.key});

  @override
  State<InHouseOrdersScreen> createState() => _InHouseOrdersScreenState();
}

class _InHouseOrdersScreenState extends State<InHouseOrdersScreen>
    with SingleTickerProviderStateMixin {
  late RestaurantFloorPlan _floorPlan;
  bool _isLoading = true;
  bool _isEditMode = false;
  String? _selectedSectionId;
  List<MenuItem> _menuItems = [];
  String? _userBranch;
  String? _userName;
  String? _error;

  late TabController _tabController;
  final GlobalKey<_FloorPlanCanvasState> _globalFloorPlanKey =
      GlobalKey<_FloorPlanCanvasState>();

  @override
  void initState() {
    super.initState();
    // Initialize with empty floor plan
    _floorPlan = RestaurantFloorPlan(
      id: 'fp_loading',
      branchId: 'loading',
      branchName: 'Loading...',
      sections: [],
    );
    _initializeScreen();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _initializeScreen() async {
    try {
      final authService = AuthService();
      final role = await authService.getUserRole();
      final prefs = await SharedPreferences.getInstance();

      // Get location based on user role
      String? location;

      if (role == UserRole.admin) {
        // For admin, use the location selected in dashboard
        location = prefs.getString('dashboard_selected_location');
        debugPrint('🔍 Admin - using dashboard selected location: $location');
      } else {
        // For branch managers, use their assigned branch
        location = await authService.getUserLocation();
        debugPrint('🔍 Branch manager - using assigned location: $location');
      }

      String? name;
      try {
        name = await authService.getUserName();
      } catch (e) {
        debugPrint('Error getting user name: $e');
      }

      debugPrint('📍 Final user location: $location');
      debugPrint('👤 User role: $role');

      if (location == null || location.isEmpty) {
        if (mounted) {
          setState(() {
            _error =
                'No branch selected. Please select a branch on the Dashboard.';
            _isLoading = false;
          });
        }
        return;
      }

      setState(() {
        _userBranch = location;
        _userName = name;
        _error = null;
      });

      await Future.wait([
        _loadFloorPlan(),
        _loadMenu(),
      ]);
    } catch (e) {
      debugPrint('Error initializing screen: $e');
      if (mounted) {
        setState(() {
          _error = 'Error initializing: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: $e')),
        );
      }
    }
  }

  Future<void> _loadFloorPlan() async {
    try {
      debugPrint('📥 Loading floor plan for location: $_userBranch');

      // Fetch floor plan from backend
      final response =
          await ApiService.get('/tables/floorplan?location=$_userBranch');

      debugPrint('✅ Floor plan loaded successfully');

      final data = response['data'];
      List<TableSection> sections = [];

      if (data != null &&
          data['sections'] != null &&
          data['sections'] is List) {
        // Parse sections from backend
        sections = (data['sections'] as List).map((sectionJson) {
          // Parse section type
          SectionType sectionType = SectionType.main_hall;
          if (sectionJson['type'] != null) {
            try {
              sectionType = SectionType.values.firstWhere(
                (e) => e.toString().split('.').last == sectionJson['type'],
                orElse: () => SectionType.main_hall,
              );
            } catch (e) {
              sectionType = SectionType.main_hall;
            }
          }

          // Parse tables
          List<RestaurantTable> tables = [];
          if (sectionJson['tables'] != null && sectionJson['tables'] is List) {
            tables = (sectionJson['tables'] as List).map((tableJson) {
              // Parse table status
              TableStatus status = TableStatus.available;
              if (tableJson['status'] != null) {
                try {
                  status = TableStatus.values.firstWhere(
                    (e) => e.toString().split('.').last == tableJson['status'],
                    orElse: () => TableStatus.available,
                  );
                } catch (e) {
                  status = TableStatus.available;
                }
              }

              // Parse table shape
              TableShape shape = TableShape.circle;
              if (tableJson['shape'] != null) {
                try {
                  shape = TableShape.values.firstWhere(
                    (e) => e.toString().split('.').last == tableJson['shape'],
                    orElse: () => TableShape.circle,
                  );
                } catch (e) {
                  shape = TableShape.circle;
                }
              }

              // Parse order items
              List<OrderItem> orderItems = [];
              if (tableJson['currentOrder'] != null &&
                  tableJson['currentOrder'] is List) {
                orderItems =
                    (tableJson['currentOrder'] as List).map((itemJson) {
                  return OrderItem(
                    id: itemJson['_id'] ?? '',
                    name: itemJson['name'] ?? '',
                    price: (itemJson['price'] as num?)?.toDouble() ?? 0.0,
                    quantity: itemJson['quantity'] ?? 1,
                    category: itemJson['category'] ?? '',
                    imageUrl: itemJson['imageUrl'],
                    spiceLevel: itemJson['spiceLevel'] ?? itemJson['spice_level'],
                    isAlcohol: itemJson['isAlcohol'] == true,
                  );
                }).toList();
              }

              return RestaurantTable(
                id: tableJson['_id'] ?? '',
                name: tableJson['name'] ?? '',
                number: tableJson['number'] ?? 0,
                capacity: tableJson['capacity'] ?? 4,
                status: status,
                posX: (tableJson['posX'] as num?)?.toDouble() ?? 0.0,
                posY: (tableJson['posY'] as num?)?.toDouble() ?? 0.0,
                width: (tableJson['width'] as num?)?.toDouble() ?? 80.0,
                height: (tableJson['height'] as num?)?.toDouble() ?? 80.0,
                rotation: (tableJson['rotation'] as num?)?.toDouble() ?? 0.0,
                shape: shape,
                sectionId: sectionJson['id'] ?? '',
                currentOrder: orderItems,
                currentOrderToken: tableJson['currentOrderToken'],
                assignedWaiter: tableJson['assignedWaiter'],
                billTotal: (tableJson['billTotal'] as num?)?.toDouble(),
              );
            }).toList();
          }

          return TableSection(
            id: sectionJson['id'] ?? '',
            name: sectionJson['name'] ?? '',
            type: sectionType,
            tables: tables,
          );
        }).where((section) {
              return section.type != SectionType.private_dining &&
              section.id != 'private';
        }).toList();
      }

      // If no sections exist, create default sections
      if (sections.isEmpty) {
        sections = [
          TableSection(
            id: 'main_hall',
            name: 'Main Hall',
            type: SectionType.main_hall,
            tables: _generateMockTables('main_hall', 1, 6),
          ),
          TableSection(
            id: 'outdoor',
            name: 'Outdoor Patio',
            type: SectionType.outdoor,
            tables: _generateMockTables('outdoor', 7, 10),
          ),
          TableSection(
            id: 'vip',
            name: 'VIP Room',
            type: SectionType.vip_room,
            tables: _generateMockTables('vip', 11, 12),
          ),
        ];
      }

      setState(() {
        _floorPlan = RestaurantFloorPlan(
          id: data?['_id'] ?? 'fp_$_userBranch',
          branchId: _userBranch ?? 'unknown',
          branchName: _userBranch ?? 'Unknown Branch',
          sections: sections,
          isEditMode: false,
        );
        _selectedSectionId = sections.isNotEmpty ? sections.first.id : null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading floor plan: $e')),
        );
      }
    }
  }

  List<RestaurantTable> _generateMockTables(
      String sectionId, int startNumber, int endNumber) {
    final tables = <RestaurantTable>[];
    int index = 0;
    final shapes = [TableShape.circle, TableShape.square, TableShape.rectangle];
    for (int i = startNumber; i <= endNumber; i++) {
      final row = index ~/ 3;
      final col = index % 3;
      final shape = shapes[i % 3];
      final width = shape == TableShape.rectangle ? 120.0 : 80.0;
      final height = shape == TableShape.rectangle ? 60.0 : 80.0;
      tables.add(
        RestaurantTable(
          id: 't_${sectionId}_$i',
          name: 'T$i',
          number: i,
          capacity: 4,
          status: [
            TableStatus.available,
            TableStatus.occupied,
            TableStatus.available
          ][i % 3],
          posX: (col * 100.0) + 20,
          posY: (row * 100.0) + 20,
          width: width,
          height: height,
          rotation: 0,
          shape: shape,
          sectionId: sectionId,
        ),
      );
      index++;
    }
    return tables;
  }

  Future<void> _loadMenu() async {
    try {
      final data = await ApiService.get('/menu');
      final list = data is Map && data['data'] is List
          ? data['data'] as List
          : (data is List ? data : []);

      setState(() {
        _menuItems = list
            .map((json) => MenuItem(
                  id: json['_id'] ?? '',
                  name: json['name'] ?? '',
                  description: json['description'] ?? '',
                  price: (json['price'] as num?)?.toDouble() ?? 0,
                  category: json['category'] ?? '',
                  imageUrl: json['imageUrl'] ?? '',
                ))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading menu: $e');
    }
  }

  TableSection _getCurrentSection() {
    if (_floorPlan.sections.isEmpty) {
      return TableSection(
        id: 'empty',
        name: 'No Sections',
        type: SectionType.main_hall,
        tables: [],
      );
    }

    return _floorPlan.sections.firstWhere(
      (s) => s.id == _selectedSectionId,
      orElse: () => _floorPlan.sections.first,
    );
  }

  Future<void> _persistTableUpdate(RestaurantTable table) async {
    if (_userBranch == null) return;
    if (_isEditMode) return;
    try {
      await ApiService.put('/tables/${table.id}', {
        'location': _userBranch,
        'sectionId': table.sectionId,
        'updateData': table.toJson(),
      });
    } catch (e) {
      debugPrint('❌ Failed to persist table update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save table changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateTableOrderSubtotal(RestaurantTable table) {
    return table.currentOrder.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Map<String, dynamic> _mapOrderItemForInHouseApi(OrderItem item) {
    return {
      'name': item.name,
      'description': '',
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl ?? '',
      'spiceLevel': item.spiceLevel,
    };
  }

  Future<void> _ensureInHouseOrderRecord(RestaurantTable table) async {
    if (_userBranch == null) return;
    if (table.currentOrder.isEmpty) return;

    final subtotal = _calculateTableOrderSubtotal(table);
    final items = table.currentOrder.map(_mapOrderItemForInHouseApi).toList();
    final branch = _userBranch!;

    // If we already have a token, update the existing record (items/total).
    final existingToken = table.currentOrderToken;
    if (existingToken != null && existingToken.trim().isNotEmpty) {
      await ApiService.patch(
        '/inhouse-orders/$existingToken?branch=${Uri.encodeComponent(branch)}',
        {
          'totalAmount': subtotal,
          'items': items,
        },
      );
      return;
    }

    // Otherwise, create a new in-house order record.
    final response = await ApiService.post('/inhouse-orders', {
      'branch': branch,
      'tableId': table.id,
      'tableNumber': table.number,
      'items': items,
      'totalAmount': subtotal,
      'waiter': table.assignedWaiter,
    });

    final token = response is Map ? response['orderToken'] as String? : null;
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      table.currentOrderToken = token;
    });
  }

  Future<void> _syncVoidRemovalToInHouseOrder(
    RestaurantTable table,
    List<OrderItem> updatedItems,
  ) async {
    if (_userBranch == null) return;

    final branch = _userBranch!;

    // Keep the in-memory table order in sync with what was voided.
    table.currentOrder = List<OrderItem>.from(updatedItems);

    // If token is missing (orders created before token persistence), try to
    // resolve the active open order for this table.
    if (table.currentOrderToken == null ||
        table.currentOrderToken!.trim().isEmpty) {
      try {
        final response = await ApiService.get(
          '/inhouse-orders-active?branch=${Uri.encodeComponent(branch)}&tableId=${Uri.encodeComponent(table.id)}',
        );
        final data = response is Map ? response['data'] : null;
        final token = data is Map ? data['orderToken'] as String? : null;
        if (token != null && token.trim().isNotEmpty) {
          setState(() {
            table.currentOrderToken = token;
          });
          await _persistTableUpdate(table);
        }
      } catch (_) {
        // Ignore lookup errors; we'll fall back to creating a record below.
      }
    }

    // Ensure we have a standalone in-house order document, then mark it voided.
    await _ensureInHouseOrderRecord(table);

    final token = table.currentOrderToken;
    if (token == null || token.trim().isEmpty) return;

    final subtotal = _calculateTableOrderSubtotal(table);
    final items = updatedItems.map(_mapOrderItemForInHouseApi).toList();

    await ApiService.patch(
      '/inhouse-orders/$token?branch=${Uri.encodeComponent(branch)}',
      {
        'void': true,
        'items': items,
        'totalAmount': subtotal,
      },
    );

    // Persist token (and updated order snapshot) to the floorplan table doc.
    // This prevents creating duplicate order docs later.
    await _persistTableUpdate(table);
  }

  void _onTableTap(RestaurantTable table) {
    _showTableOptionsBottomSheet(table);
  }

  void _onTableLongPress(RestaurantTable table) {
    if (!_isEditMode) return;
    _showTableEditDialog(table);
  }

  void _showTableOptionsBottomSheet(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TableOptionsBottomSheet(
        table: table,
        menuItems: _menuItems,
        onTakeOrder: () {
          Navigator.pop(context);
          _showOrderTakingScreen(table);
        },
        onBill: () {
          if (table.currentOrder.isEmpty) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(
                content: Text('Cannot bill: no items in the order'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          Navigator.pop(context);
          // Skip awaiting_bill status, go directly to billing
          _showBillingScreen(table);
        },
        onPrintKitchen: () {
          Navigator.pop(context);
          _printKitchenSlip(table);
        },
        onPrintBill: () {
          Navigator.pop(context);
          _printBillSlip(table);
        },
        onToggleReserve: () {
          Navigator.pop(context);
          _toggleTableReservation(table);
        },
      ),
    );
  }

  void _toggleTableReservation(RestaurantTable table) {
    // Reservation is only for empty tables. Once an order exists, the table
    // must stay occupied until billing clears it.
    if (table.currentOrder.isNotEmpty ||
        table.status == TableStatus.occupied ||
        table.status == TableStatus.awaitingBill) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Table cannot be changed until billed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (table.status == TableStatus.reserved) {
        table.status = TableStatus.available;
      } else {
        table.status = TableStatus.reserved;
      }
    });

    _persistTableUpdate(table);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          table.status == TableStatus.reserved
              ? 'Table ${table.number} reserved'
              : 'Table ${table.number} is now available',
        ),
        backgroundColor:
            table.status == TableStatus.reserved ? Colors.blue : Colors.green,
      ),
    );
  }

  void _showOrderTakingScreen(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderTakingScreen(
        table: table,
        branch: _userBranch ?? 'Comox',
        menuItems: _menuItems,
        onVoidItemRemoved: (table, updatedItems) async {
          try {
            await _syncVoidRemovalToInHouseOrder(table, updatedItems);
          } catch (e) {
            debugPrint('❌ Failed to sync void removal to DB: $e');
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('Failed to sync void: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onSaveOrder: (updatedTable) async {
          setState(() {
            final sectionIndex = _floorPlan.sections
                .indexWhere((s) => s.id == _selectedSectionId);
            final tableIndex = _floorPlan.sections[sectionIndex].tables
                .indexWhere((t) => t.id == updatedTable.id);
            _floorPlan.sections[sectionIndex].tables[tableIndex] = updatedTable;
            // Once an order is taken, the table is occupied until billing.
            updatedTable.status = TableStatus.occupied;
          });

          try {
            await _ensureInHouseOrderRecord(updatedTable);
            await _persistTableUpdate(updatedTable);
          } catch (e) {
            debugPrint('❌ Failed to save in-house order record: $e');
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save order: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          if (!mounted) return;

          // Close the order taking bottom sheet
          Navigator.pop(this.context);

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text('Table ${updatedTable.number} order saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showBillingScreen(RestaurantTable table) {
    if (table.currentOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot bill: no items in the order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BillingScreen(
        table: table,
        onProcessBill: (paymentMethod, tip, billAmount) async {
          Navigator.pop(context);
          await _processTableBill(table, paymentMethod, tip, billAmount);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _processTableBill(RestaurantTable table, String paymentMethod,
      double tip, double billAmount) async {
    final branch = _userBranch;
    var token = table.currentOrderToken;

    // If the table has an order but no token yet, create the standalone order
    // document first so billing/analytics can track it.
    if (token == null || token.trim().isEmpty) {
      try {
        await _ensureInHouseOrderRecord(table);
        token = table.currentOrderToken;
      } catch (e) {
        debugPrint('❌ Failed to create in-house order before billing: $e');
      }
    }

    // First, update the standalone in-house order record (so analytics can see billing).
    if (branch != null && token != null && token.trim().isNotEmpty) {
      try {
        await ApiService.patch(
          '/inhouse-orders/$token?branch=${Uri.encodeComponent(branch)}',
          {
            'paymentMethod': paymentMethod,
            'billAmount': billAmount,
            'tip': tip,
            'status': 'billed',
          },
        );
      } catch (e) {
        debugPrint('❌ Failed to mark in-house order billed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to finalize bill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Continue clearing the table even if analytics update fails.
      }
    }

    setState(() {
      table.status = TableStatus.available;
      table.currentOrder.clear();
      table.currentOrderToken = null;
      table.billTotal = null;
      table.assignedWaiter = null;
    });

    await _persistTableUpdate(table);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Bill processed via $paymentMethod (Tip: \$${tip.toStringAsFixed(2)}). Table cleared.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showTableEditDialog(RestaurantTable table) {
    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditTableDialog(
        table: table,
        onTableUpdated: (updatedTable) {
          setState(() {
            // Update table in the state
            final sectionIndex = _floorPlan.sections
                .indexWhere((s) => s.id == _selectedSectionId);
            final tableIndex = _floorPlan.sections[sectionIndex].tables
                .indexWhere((t) => t.id == table.id);
            _floorPlan.sections[sectionIndex].tables[tableIndex] = updatedTable;
          });
          _persistTableUpdate(updatedTable);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Table "${updatedTable.name}" updated')),
          );
        },
        onTableDeleted: () {
          Navigator.pop(context); // Close edit dialog first
          _deleteTable(table);
        },
      ),
    );
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    // Validation: cannot delete if table has active orders or is occupied
    if (table.currentOrder.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete table with active orders'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (table.status == TableStatus.occupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete occupied table'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Table',
      message: 'Are you sure you want to delete table "${table.name}"?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      final sectionIndex =
          _floorPlan.sections.indexWhere((s) => s.id == _selectedSectionId);
      _floorPlan.sections[sectionIndex].tables
          .removeWhere((t) => t.id == table.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Table "${table.name}" deleted')),
    );
  }

  void _addNewTable() {
    final section = _getCurrentSection();

    final newTableNumber = (section.tables.isNotEmpty
            ? section.tables
                .map((t) => t.number)
                .reduce((a, b) => a > b ? a : b)
            : 0) +
        1;

    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CreateTableDialog(
        onTableCreated: (name, capacity, shape) {
          final initialWidth = shape == TableShape.rectangle ? 120.0 : 80.0;
          final initialHeight = shape == TableShape.rectangle ? 60.0 : 80.0;
          final newTable = RestaurantTable(
            id: 't_${section.id}_$newTableNumber',
            name: name,
            number: newTableNumber,
            capacity: capacity,
            status: TableStatus.available,
            posX: 100,
            posY: 100,
            width: initialWidth,
            height: initialHeight,
            rotation: 0,
            shape: shape,
            sectionId: section.id,
          );

          setState(() => section.tables.add(newTable));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Table "$name" added')),
          );
        },
      ),
    );
  }

  Future<void> _printKitchenSlip(RestaurantTable table) async {
    try {
      final items = table.currentOrder.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'spiceLevel': item.spiceLevel,
        'isAlcohol': item.isAlcohol,
      }).toList();

      await PrinterService.printKitchenSlip(
        'Table ${table.number}',
        items,
        location: _userBranch ?? 'Main Restaurant',
        orderTime: DateTime.now(),
        orderType: 'table',
        tableNumber: table.number.toString(),
        waiterName: table.assignedWaiter ?? _userName,
        branchId: _userBranch,
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

  Future<void> _printBillSlip(RestaurantTable table) async {
    try {
      LoggerService.info(
        'Print bill requested for table ${table.number} (${_userBranch ?? 'unknown branch'}).',
        'InHouseOrders',
      );
      
      final items = table.currentOrder.map((item) => {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'spiceLevel': item.spiceLevel,
        'isAlcohol': item.isAlcohol,
      }).toList();

      final subtotal = _calculateTableOrderSubtotal(table);

      await PrinterService.printBillSlip(
        'Table ${table.number}',
        subtotal,
        items: items.cast<Map<String, dynamic>>(),
        orderType: 'table',
        tableNumber: table.number.toString(),
        waiterName: table.assignedWaiter ?? _userName,
        branchId: _userBranch,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill slip printed successfully')),
        );
      }
    } catch (e) {
      LoggerService.error('Error printing bill slip', e, null, 'InHouseOrders');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing bill slip: $e')),
        );
      }
    }
  }

  void _toggleEditMode() async {
    // If currently in edit mode, save before exiting
    if (_isEditMode) {
      await _saveFloorPlan();
      return; // Exit after saving
    }

    // Enter edit mode
    setState(() => _isEditMode = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit mode ON - Changes will auto-save when you finish'),
      ),
    );
  }

  Future<void> _saveFloorPlan() async {
    try {
      if (_userBranch == null || _userBranch!.isEmpty) {
        throw Exception(
            'No branch selected. Please select a branch on the Dashboard.');
      }
      debugPrint('💾 Saving floor plan for location: $_userBranch');

      final sectionsData = _floorPlan.sections.map((s) {
        return {
          'id': s.id,
          'name': s.name,
          'type': s.type.toString().split('.').last,
          'tables': s.tables.map((t) => t.toJson()).toList(),
        };
      }).toList();

      debugPrint('📦 Sections data: ${sectionsData.length} sections');
      debugPrint(
          '📦 First section: ${sectionsData.isNotEmpty ? sectionsData[0]['name'] : 'none'}');

      final response = await ApiService.patch('/tables/floorplan', {
        'branchId': _userBranch,
        'sections': sectionsData,
      });

      debugPrint('✅ Floor plan saved successfully: ${response['message']}');

      setState(() => _isEditMode = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor plan saved successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving floor plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _clearAllTables() async {
    // Show confirmation dialog
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Clear All Tables',
      message: 'Are you sure you want to clear ALL tables? This will reset all tables to available and remove all orders.',
      confirmText: 'Clear All',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (confirmed != true) return;

    try {
      // Clear all tables in memory
      for (var section in _floorPlan.sections) {
        for (var table in section.tables) {
          table.status = TableStatus.available;
          table.currentOrder.clear();
          table.currentOrderToken = null;
          table.billTotal = null;
          table.assignedWaiter = null;
        }
      }

      setState(() {});

      // Persist to backend
      await _saveFloorPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All tables cleared successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error clearing tables: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing tables: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'In-House Tables',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: _buildDrawer(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'In-House Tables',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: _buildDrawer(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error Loading Floor Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initializeScreen();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_floorPlan.sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'In-House Tables',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: _buildDrawer(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'No floor plan sections available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check branch data or try again.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializeScreen();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentSection = _getCurrentSection();

    return Scaffold(
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
          'In-House Tables',
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
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAllTables,
            tooltip: 'Clear All Tables',
          ),
          IconButton(
            icon: Icon(_isEditMode ? Icons.done : Icons.edit),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(
                  () => _selectedSectionId = _floorPlan.sections[index].id);
            },
            tabs: _floorPlan.sections.map((s) => Tab(text: s.name)).toList(),
          ),
          Expanded(
            child: Stack(
              children: [
                FloorPlanCanvas(
                  key: _globalFloorPlanKey,
                  section: currentSection,
                  isEditMode: _isEditMode,
                  onTableTap: _onTableTap,
                  onTableLongPress: _onTableLongPress,
                  onAddTable: _addNewTable,
                ),
                // Floating zoom and fullscreen buttons
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        backgroundColor: const Color(0xFFFF7A00),
                        onPressed: () {
                          // Will be controlled by FloorPlanCanvas
                          _globalFloorPlanKey.currentState?._zoomIn();
                        },
                        tooltip: 'Zoom In',
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        backgroundColor: const Color(0xFFFF7A00),
                        onPressed: () {
                          _globalFloorPlanKey.currentState?._zoomOut();
                        },
                        tooltip: 'Zoom Out',
                        child: const Icon(Icons.remove, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'fullscreen',
                        mini: true,
                        backgroundColor: const Color(0xFFFF7A00),
                        onPressed: () {
                          _globalFloorPlanKey.currentState?._enterFullScreen();
                        },
                        tooltip: 'Full Screen',
                        child: const Icon(Icons.fullscreen, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'fit_screen',
                        mini: true,
                        backgroundColor: const Color(0xFFFF7A00),
                        onPressed: () {
                          _globalFloorPlanKey.currentState?._fitToScreen();
                        },
                        tooltip: 'Fit to Screen',
                        child: const Icon(Icons.fit_screen, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
                isSelected: true,
                onTap: () {},
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
              // Menu Management
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
              // User Management
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
}

// ============================================================================
// FLOOR PLAN CANVAS
// ============================================================================

class FloorPlanCanvas extends StatefulWidget {
  final TableSection section;
  final bool isEditMode;
  final Function(RestaurantTable) onTableTap;
  final Function(RestaurantTable) onTableLongPress;
  final VoidCallback? onAddTable;

  const FloorPlanCanvas({
    Key? key,
    required this.section,
    required this.isEditMode,
    required this.onTableTap,
    required this.onTableLongPress,
    this.onAddTable,
  }) : super(key: key);

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas> {
  late TransformationController _transformationController;
  RestaurantTable? _draggingTable;
  late GlobalKey _containerKey;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _containerKey = GlobalKey();
    // Fit to screen on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToScreen();
    });
  }

  void _fitToScreen() {
    if (!mounted) return;
    final containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return;

    final containerSize = containerBox.size;
    final gridWidth = widget.section.sectionWidth;
    final gridHeight = widget.section.sectionHeight;

    // Calculate scale to fit grid in container while maintaining aspect ratio
    final scaleX = containerSize.width / gridWidth;
    final scaleY = containerSize.height / gridHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% to add padding

    // Center the grid
    final scaledWidth = gridWidth * scale;
    final scaledHeight = gridHeight * scale;
    final offsetX = (containerSize.width - scaledWidth) / 2;
    final offsetY = (containerSize.height - scaledHeight) / 2;

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(offsetX, offsetY, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomIn() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.3, 5.0);
    final scaleDelta = newScale / currentScale;
    
    // Get current translation
    final translation = currentMatrix.getTranslation();
    
    // Apply zoom centered on current view
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
          translation.x * scaleDelta, translation.y * scaleDelta, 0, 1)
      ..scaleByDouble(newScale, newScale, 1, 1);
  }

  void _zoomOut() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.3, 5.0);
    final scaleDelta = newScale / currentScale;
    
    // Get current translation
    final translation = currentMatrix.getTranslation();
    
    // Apply zoom centered on current view
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
          translation.x * scaleDelta, translation.y * scaleDelta, 0, 1)
      ..scaleByDouble(newScale, newScale, 1, 1);
  }

  void _enterFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenFloorPlan(
          section: widget.section,
          isEditMode: widget.isEditMode,
          onTableTap: widget.onTableTap,
          onTableLongPress: widget.onTableLongPress,
          onAddTable: widget.onAddTable,
        ),
      ),
    );
  }

  void _onTableDragStart(RestaurantTable table, TapDownDetails details) {
    if (!widget.isEditMode) return;
    setState(() {
      _draggingTable = table;
    });
  }

  void _onTableDragUpdate(RestaurantTable table, Offset delta) {
    if (!widget.isEditMode || _draggingTable != table) return;
    setState(() {
      table.posX = (table.posX + delta.dx)
          .clamp(0, widget.section.sectionWidth - table.width);
      table.posY = (table.posY + delta.dy)
          .clamp(0, widget.section.sectionHeight - table.height);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _containerKey,
      color: Colors.white,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.3,
        maxScale: 5.0,
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.all(50),
        constrained: false,
        child: Stack(
          children: [
            Container(
              width: widget.section.sectionWidth,
              height: widget.section.sectionHeight,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
            ...widget.section.tables.map((table) {
              return Positioned(
                left: table.posX,
                top: table.posY,
                child: GestureDetector(
                  onTapDown: widget.isEditMode ? (details) => _onTableDragStart(table, details) : null,
                  onTapUp: (_) {
                    if (_draggingTable == null || !widget.isEditMode) {
                      widget.onTableTap(table);
                    }
                    if (widget.isEditMode) {
                      setState(() => _draggingTable = null);
                    }
                  },
                  onLongPress: () => widget.onTableLongPress(table),
                  onPanUpdate: widget.isEditMode
                      ? (details) => _onTableDragUpdate(table, details.delta)
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      TableWidget(
                        table: table,
                        isSelected: false,
                        isEditMode: widget.isEditMode,
                      ),
                      // Resize handles in edit mode
                      if (widget.isEditMode) ...[
                        if (table.shape == TableShape.rectangle) ...[
                          Positioned(
                            right: -10,
                            top: (table.height / 2) - 10,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    table.width = (table.width + details.delta.dx)
                                        .clamp(60, 240)
                                        .toDouble();
                                  });
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.green[400],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.green[700]!, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -10,
                            left: (table.width / 2) - 10,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  table.height =
                                      (table.height + details.delta.dy)
                                          .clamp(40, 200)
                                          .toDouble();
                                });
                              },
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.green[400],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.green[700]!, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else
                        Builder(
                          builder: (context) {
                            final diagonal = table.shape == TableShape.circle
                                ? table.width
                                : sqrt(table.width * table.width +
                                    table.height * table.height);
                            return Positioned(
                              bottom: (diagonal - table.height) / 2 - 10,
                              right: (diagonal - table.width) / 2 - 10,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeDownRight,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      final delta = details.delta.dx.abs() >
                                              details.delta.dy.abs()
                                          ? details.delta.dx
                                          : details.delta.dy;
                                      final newSize = (table.width + delta)
                                          .clamp(30, 200)
                                          .toDouble();
                                      table.width = newSize;
                                      table.height = newSize;
                                    });
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.green[400],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.green[700]!, width: 2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          if (widget.isEditMode && widget.onAddTable != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: widget.onAddTable!,
                backgroundColor: const Color(0xFFFF7A00),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class TableWidget extends StatelessWidget {
  final RestaurantTable table;
  final bool isSelected;
  final bool isEditMode;

  const TableWidget({
    super.key,
    required this.table,
    this.isSelected = false,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the required size to prevent clipping when rotated
    // For a rotated rectangle, the diagonal becomes the bounding box
    final diagonal = table.shape == TableShape.circle
        ? table.width
        : sqrt(table.width * table.width + table.height * table.height);

    return SizedBox(
      width: diagonal,
      height: diagonal,
      child: Center(
        child: Transform.rotate(
          angle: (table.rotation * 3.14159265359) /
              180, // Convert degrees to radians
          alignment: Alignment.center,
          child: SizedBox(
            width: table.width,
            height: table.height,
            child: Container(
              decoration: BoxDecoration(
                color: table.statusColor.withValues(alpha: 0.7),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey[400]!,
                  width: isSelected ? 3 : 2,
                ),
                shape: table.shape == TableShape.circle
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: table.shape == TableShape.rectangle
                    ? BorderRadius.circular(8)
                    : (table.shape == TableShape.square
                        ? BorderRadius.circular(4)
                        : null),
                boxShadow: isEditMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.5),
                          blurRadius: 5,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          table.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${table.capacity}p',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                        if (table.currentOrder.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${table.currentOrder.length} items',
                                style: const TextStyle(
                                    fontSize: 8, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Rotation indicator in edit mode
                  if (isEditMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${table.rotation.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
  }
}

class TableOptionsBottomSheet extends StatelessWidget {
  final RestaurantTable table;
  final List<MenuItem> menuItems;
  final VoidCallback onTakeOrder;
  final VoidCallback onBill;
  final VoidCallback onPrintKitchen;
  final VoidCallback onPrintBill;
  final VoidCallback onToggleReserve;

  const TableOptionsBottomSheet({
    super.key,
    required this.table,
    required this.menuItems,
    required this.onTakeOrder,
    required this.onBill,
    required this.onPrintKitchen,
    required this.onPrintBill,
    required this.onToggleReserve,
  });

  @override
  Widget build(BuildContext context) {
    final canBill = table.currentOrder.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Table ${table.number}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(table.statusLabel),
                backgroundColor: table.statusColor,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Capacity: ${table.capacity} | Items: ${table.currentOrder.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (table.assignedWaiter != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Waiter: ${table.assignedWaiter}',
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTakeOrder,
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Take Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canBill ? onBill : null,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Settle Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (table.currentOrder.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPrintKitchen,
                    icon: const Icon(Icons.print),
                    label: const Text('Kitchen Slip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPrintBill,
                    icon: const Icon(Icons.receipt),
                    label: const Text('Print Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleReserve,
              icon: Icon(
                table.status == TableStatus.reserved
                    ? Icons.event_busy
                    : Icons.event_available,
              ),
              label: Text(
                table.status == TableStatus.reserved ? 'Unreserve' : 'Reserve',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor:
                    table.status == TableStatus.reserved ? Colors.red : Colors.blue,
                side: BorderSide(
                  color: table.status == TableStatus.reserved
                      ? Colors.red
                      : Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderTakingScreen extends StatefulWidget {
  final RestaurantTable table;
  final String branch;
  final List<MenuItem> menuItems;
  final Future<void> Function(
      RestaurantTable table, List<OrderItem> updatedItems)? onVoidItemRemoved;
  final Function(RestaurantTable) onSaveOrder;
  final VoidCallback onCancel;

  const OrderTakingScreen({
    super.key,
    required this.table,
    required this.branch,
    required this.menuItems,
    this.onVoidItemRemoved,
    required this.onSaveOrder,
    required this.onCancel,
  });

  @override
  State<OrderTakingScreen> createState() => _OrderTakingScreenState();
}

class _OrderTakingScreenState extends State<OrderTakingScreen> {
  late List<OrderItem> _orderItems;
  late List<OrderItem> _initialOrderItems; // Track originally saved items
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _orderItems = List.from(widget.table.currentOrder);
    _initialOrderItems =
        List.from(widget.table.currentOrder); // Save initial state
  }

  List<MenuItem> _getFilteredItems() {
    if (_selectedCategory == 'All') return widget.menuItems;
    return widget.menuItems
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  List<String> _getCategories() {
    final categories = widget.menuItems.map((e) => e.category).toSet().toList();
    return ['All', ...categories];
  }

  Future<void> _addItemToOrder(MenuItem item) async {
    final spiceLevel = await SpiceLevelPickerDialog.show(context);
    if (!mounted) return;

    final existingIndex = _orderItems.indexWhere(
      (oi) => oi.id == item.id && oi.spiceLevel == spiceLevel,
    );
    if (existingIndex >= 0) {
      setState(() => _orderItems[existingIndex].quantity++);
    } else {
      setState(() {
        _orderItems.add(OrderItem(
          id: item.id,
          name: item.name,
          price: item.price,
          category: item.category,
          imageUrl: item.imageUrl,
          spiceLevel: spiceLevel,
          isAlcohol: item.isAlcohol,
        ));
      });
    }
  }

  void _removeItemFromOrder(OrderItem item) async {
    // Check if this item was in the initial saved order
    final wasInitiallySaved = _initialOrderItems.any(
      (oi) => oi.id == item.id && oi.spiceLevel == item.spiceLevel,
    );

    if (wasInitiallySaved && _initialOrderItems.isNotEmpty) {
      // Item was previously saved, require void code
      await _showVoidCodeDialog(item);
    } else {
      // New item not yet saved, can be removed freely
      setState(() => _orderItems.removeWhere((oi) => oi.id == item.id));
    }
  }

  Future<void> _showVoidCodeDialog(OrderItem item) async {
    final voidCodeController = TextEditingController();

    final result = await DialogUtils.showAnimatedDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Void Code Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Removing: ${item.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This item was previously saved. Enter void code to remove:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: voidCodeController,
              decoration: const InputDecoration(
                labelText: 'Void Code',
                border: OutlineInputBorder(),
                hintText: 'Enter void code',
              ),
              textCapitalization: TextCapitalization.characters,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final voidCode = voidCodeController.text.trim();
              if (voidCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter void code')),
                );
                return;
              }

              // Validate + apply void on backend (sets void=true and voidedAt).
              try {
                final branch = widget.branch;

                // Resolve token if missing (legacy tables/orders).
                var token = widget.table.currentOrderToken;
                if (token == null || token.trim().isEmpty) {
                  final active = await ApiService.get(
                    '/inhouse-orders-active?branch=${Uri.encodeComponent(branch)}&tableId=${Uri.encodeComponent(widget.table.id)}',
                  );
                  final data = active is Map ? active['data'] : null;
                  final resolved = data is Map ? data['orderToken'] as String? : null;
                  if (resolved != null && resolved.trim().isNotEmpty) {
                    token = resolved;
                    widget.table.currentOrderToken = resolved;
                  }
                }

                if (token == null || token.trim().isEmpty) {
                  throw Exception('No active in-house order token found for this table');
                }

                final response = await ApiService.post(
                  '/inhouse-orders/$token/void',
                  {
                    'branch': branch,
                    'voidCode': voidCode,
                    'itemsToRemove': [
                      {
                        'name': item.name,
                        'price': item.price,
                        'spiceLevel': item.spiceLevel,
                      }
                    ],
                  },
                );

                if (response is Map && response['success'] == true) {
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                  return;
                }

                throw Exception('Void failed');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid void code or server error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
            ),
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _orderItems.removeWhere(
          (oi) => oi.id == item.id && oi.spiceLevel == item.spiceLevel,
        );
      });

      // Persist the void action to the standalone in-house order document.
      // This makes sure analytics/DB reflect the void immediately.
      widget.table.currentOrder = List<OrderItem>.from(_orderItems);
      await widget.onVoidItemRemoved?.call(
        widget.table,
        List<OrderItem>.from(_orderItems),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} removed from order'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  double _getOrderTotal() =>
      _orderItems.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    final categories = _getCategories();
    final filteredItems = _getFilteredItems();

    return Container(
      color: Colors.white,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order for Table ${widget.table.number}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: categories
                  .map((cat) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return MenuItemCard(
                  item: item,
                  onAdd: () => _addItemToOrder(item),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Order',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _orderItems.isEmpty
                    ? Text('No items',
                        style: TextStyle(color: Colors.grey[600]))
                    : Column(
                        children: _orderItems
                            .map((item) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                            '${item.name} x${item.quantity}',
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      Text(
                                          '\$${item.subtotal.toStringAsFixed(2)}'),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () =>
                                            _removeItemFromOrder(item),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${_getOrderTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A00),
                        ),
                        onPressed: () {
                          widget.table.currentOrder = _orderItems;
                          setState(() {
                            _initialOrderItems = List.from(
                                _orderItems); // Update initial items after save
                          });
                          widget.onSaveOrder(widget.table);
                        },
                        child: const Text('Save Order',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onAdd;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: item.imageUrl.isNotEmpty
                    ? Image.asset(item.imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.fastfood,
                        color: Color(0xFFFF7A00), size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFFFF7A00),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BillingScreen extends StatefulWidget {
  final RestaurantTable table;
  final Function(String, double, double)
      onProcessBill; // paymentMethod, tip, billAmount
  final VoidCallback onCancel;

  const BillingScreen({
    super.key,
    required this.table,
    required this.onProcessBill,
    required this.onCancel,
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  double _tipPercentage = 0;
  String _selectedPaymentMethod = 'Cash';

  double _getSubtotal() =>
      widget.table.currentOrder.fold(0, (sum, item) => sum + item.subtotal);

  double _getTip() => _getSubtotal() * (_tipPercentage / 100);

  double _getTotal() => _getSubtotal() + _getTip();

  @override
  Widget build(BuildContext context) {
    final subtotal = _getSubtotal();
    final tip = _getTip();
    final total = _getTotal();

    return Container(
      color: Colors.white,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill - Table ${widget.table.number}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...widget.table.currentOrder
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${item.name} x${item.quantity}',
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text('\$${item.subtotal.toStringAsFixed(2)}'),
                              ],
                            ),
                          ))
                      .toList(),
                  const Divider(height: 24),
                  const Text('Tip',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [0, 10, 15, 20]
                        .map((percent) => Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _tipPercentage = percent.toDouble()),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _tipPercentage == percent
                                        ? const Color(0xFFFF7A00)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('$percent%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _tipPercentage == percent
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment Method',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Cash', 'Card', 'Mobile']
                        .map((method) => Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selectedPaymentMethod = method),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedPaymentMethod == method
                                        ? Colors.green
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(method,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _selectedPaymentMethod == method
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('\$${subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tip:'),
                    Text('\$${tip.toStringAsFixed(2)}'),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () => widget.onProcessBill(
                          _selectedPaymentMethod,
                          _getTip(),
                          _getTotal(),
                        ),
                        child: const Text('Process Payment',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class TableEditDialog extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onDelete;
  final Function(TableStatus) onStatusChange;

  const TableEditDialog({
    super.key,
    required this.table,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Table ${table.number}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioGroup<TableStatus>(
            groupValue: table.status,
            onChanged: (newStatus) {
              if (newStatus == null) return;
              onStatusChange(newStatus);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: TableStatus.values
                  .map((status) => RadioListTile<TableStatus>(
                        title: Text(status.name.replaceAll('_', ' ')),
                        value: status,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onDelete();
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

// New comprehensive edit table dialog
class EditTableDialog extends StatefulWidget {
  final RestaurantTable table;
  final Function(RestaurantTable) onTableUpdated;
  final VoidCallback onTableDeleted;

  const EditTableDialog({
    super.key,
    required this.table,
    required this.onTableUpdated,
    required this.onTableDeleted,
  });

  @override
  State<EditTableDialog> createState() => _EditTableDialogState();
}

class _EditTableDialogState extends State<EditTableDialog> {
  late String _tableName;
  late int _capacity;
  late TableShape _shape;
  late double _width;
  late double _height;
  late double _rotation;

  @override
  void initState() {
    super.initState();
    _tableName = widget.table.name;
    _capacity = widget.table.capacity;
    _shape = widget.table.shape;
    _width = widget.table.width;
    _height = widget.table.height;
    _rotation = widget.table.rotation;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Table'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Name
            const Text('Table Name:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => _tableName = value,
              decoration: InputDecoration(
                hintText: 'e.g., T1, Table 12',
                border: const OutlineInputBorder(),
                prefixText: _tableName.isEmpty
                    ? ''
                    : _tableName.isNotEmpty
                        ? ''
                        : '',
                isDense: true,
              ),
              controller: TextEditingController(text: _tableName),
            ),
            const SizedBox(height: 16),

            // Seating Capacity
            const Text('Seating Capacity:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _capacity.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: '$_capacity seats',
                    onChanged: (value) =>
                        setState(() => _capacity = value.toInt()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '$_capacity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Shape
            const Text('Table Shape:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TableShape.values
                  .map((shape) => ChoiceChip(
                        label: Text(shape.name.capitalize()),
                        selected: _shape == shape,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _shape = shape;
                            final maxSide = _width > _height ? _width : _height;
                            if (_shape == TableShape.rectangle) {
                              _width = maxSide;
                              if (_height >= _width) {
                                _height =
                                    (maxSide * 0.6).clamp(30, 200).toDouble();
                              }
                            } else {
                              _width = maxSide;
                              _height = maxSide;
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Width
            const Text('Width:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _width,
                    min: 30,
                    max: 200,
                    divisions: 17,
                    label: '${_width.toStringAsFixed(0)}px',
                    onChanged: (value) => setState(() {
                      _width = value;
                      if (_shape != TableShape.rectangle) {
                        _height = value;
                      }
                    }),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_width.toStringAsFixed(0)}px',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Height
            const Text('Height:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _height,
                    min: 30,
                    max: 200,
                    divisions: 17,
                    label: '${_height.toStringAsFixed(0)}px',
                    onChanged: (value) => setState(() {
                      _height = value;
                      if (_shape != TableShape.rectangle) {
                        _width = value;
                      }
                    }),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_height.toStringAsFixed(0)}px',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rotation
            const Text('Rotation:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _rotation,
                    min: 0,
                    max: 360,
                    divisions: 36,
                    label: '${_rotation.toStringAsFixed(0)}°',
                    onChanged: (value) => setState(() => _rotation = value),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${_rotation.toStringAsFixed(0)}°',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Snap to angle buttons
            const Text('Quick Angles:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [0, 45, 90, 135, 180, 225, 270, 315]
                  .map((angle) => ActionChip(
                        label: Text('$angle°'),
                        onPressed: () =>
                            setState(() => _rotation = angle.toDouble()),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: widget.onTableDeleted,
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.table.name = _tableName;
            widget.table.capacity = _capacity;
            widget.table.shape = _shape;
            widget.table.width = _width;
            widget.table.height = _height;
            widget.table.rotation = _rotation;
            widget.onTableUpdated(widget.table);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Create table dialog for new tables
class CreateTableDialog extends StatefulWidget {
  final Function(String name, int capacity, TableShape shape) onTableCreated;

  const CreateTableDialog({super.key, required this.onTableCreated});

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog> {
  late String _tableName = '';
  late int _capacity = 4;
  late TableShape _shape = TableShape.circle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Table'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Name
            const Text('Table Name:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => _tableName = value,
              decoration: const InputDecoration(
                hintText: 'e.g., T1, Table 12',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Seating Capacity
            const Text('Seating Capacity:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _capacity.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: '$_capacity seats',
                    onChanged: (value) =>
                        setState(() => _capacity = value.toInt()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '$_capacity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Shape
            const Text('Table Shape:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TableShape.values
                  .map((shape) => ChoiceChip(
                        label: Text(shape.name.capitalize()),
                        selected: _shape == shape,
                        onSelected: (selected) =>
                            setState(() => _shape = shape),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _tableName.isEmpty
              ? null
              : () {
                  widget.onTableCreated(_tableName, _capacity, _shape);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gridSize = 20.0;
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

// ============================================================================
// FULL SCREEN FLOOR PLAN
// ============================================================================

class FullScreenFloorPlan extends StatefulWidget {
  final TableSection section;
  final bool isEditMode;
  final Function(RestaurantTable) onTableTap;
  final Function(RestaurantTable) onTableLongPress;
  final VoidCallback? onAddTable;

  const FullScreenFloorPlan({
    super.key,
    required this.section,
    required this.isEditMode,
    required this.onTableTap,
    required this.onTableLongPress,
    this.onAddTable,
  });

  @override
  State<FullScreenFloorPlan> createState() => _FullScreenFloorPlanState();
}

class _FullScreenFloorPlanState extends State<FullScreenFloorPlan> {
  late TransformationController _transformationController;
  RestaurantTable? _draggingTable;
  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    // Fit to screen after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToScreen();
    });
  }

  void _fitToScreen() {
    if (!mounted) return;
    final containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return;

    final containerSize = containerBox.size;
    final gridWidth = widget.section.sectionWidth;
    final gridHeight = widget.section.sectionHeight;

    // Calculate scale to fit grid in full screen while maintaining aspect ratio
    final scaleX = containerSize.width / gridWidth;
    final scaleY = containerSize.height / gridHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.95; // 95% to add small padding

    // Center the grid
    final scaledWidth = gridWidth * scale;
    final scaledHeight = gridHeight * scale;
    final offsetX = (containerSize.width - scaledWidth) / 2;
    final offsetY = (containerSize.height - scaledHeight) / 2;

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(offsetX, offsetY, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _onTableDragStart(RestaurantTable table, TapDownDetails details) {
    if (!widget.isEditMode) return;
    setState(() {
      _draggingTable = table;
    });
  }

  void _onTableDragUpdate(RestaurantTable table, Offset delta) {
    if (!widget.isEditMode || _draggingTable != table) return;
    setState(() {
      table.posX = (table.posX + delta.dx)
          .clamp(0, widget.section.sectionWidth - table.width);
      table.posY = (table.posY + delta.dy)
          .clamp(0, widget.section.sectionHeight - table.height);
    });
  }

  void _zoomIn() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.3, 5.0);
    final scaleDelta = newScale / currentScale;
    
    // Get current translation
    final translation = currentMatrix.getTranslation();
    
    // Apply zoom centered on current view
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
          translation.x * scaleDelta, translation.y * scaleDelta, 0, 1)
      ..scaleByDouble(newScale, newScale, 1, 1);
  }

  void _zoomOut() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.3, 5.0);
    final scaleDelta = newScale / currentScale;
    
    // Get current translation
    final translation = currentMatrix.getTranslation();
    
    // Apply zoom centered on current view
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
          translation.x * scaleDelta, translation.y * scaleDelta, 0, 1)
      ..scaleByDouble(newScale, newScale, 1, 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7A00),
        title: const Text('Floor Plan - Full Screen', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.white),
            onPressed: _fitToScreen,
            tooltip: 'Fit to Screen',
          ),
        ],
      ),
      body: Container(
        key: _containerKey,
        color: Colors.black,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.3,
          maxScale: 5.0,
          panEnabled: true,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(50),
          constrained: false,
          child: Stack(
            children: [
              Container(
                width: widget.section.sectionWidth,
                height: widget.section.sectionHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[400]!, width: 3),
                ),
                child: CustomPaint(
                  painter: GridPainter(),
                ),
              ),
              ...widget.section.tables.map((table) {
                return Positioned(
                  left: table.posX,
                  top: table.posY,
                  child: GestureDetector(
                    onTapDown: widget.isEditMode ? (details) => _onTableDragStart(table, details) : null,
                    onTapUp: (_) {
                      if (_draggingTable == null || !widget.isEditMode) {
                        widget.onTableTap(table);
                      }
                      if (widget.isEditMode) {
                        setState(() => _draggingTable = null);
                      }
                    },
                    onLongPress: () => widget.onTableLongPress(table),
                    onPanUpdate: widget.isEditMode
                        ? (details) => _onTableDragUpdate(table, details.delta)
                        : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        TableWidget(
                          table: table,
                          isSelected: false,
                          isEditMode: widget.isEditMode,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              if (widget.isEditMode && widget.onAddTable != null)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFFFF7A00),
                    onPressed: widget.onAddTable,
                    tooltip: 'Add Table',
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
