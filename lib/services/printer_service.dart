import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

import '../storage/printer_storage.dart';
import '../utils/ip_validator.dart';
import 'logger_service.dart';

enum PrinterRole { kitchen, bill }

enum PrinterCommandMode { escPos, rawText }

class NetworkPrinter {
  static const Duration connectionTimeout = Duration(milliseconds: 2000);
  static const Duration sessionReleaseDelay = Duration(milliseconds: 120);

  static Future<void> sendBytes({
    required String ip,
    required int port,
    required List<int> bytes,
  }) async {
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    var destroyed = false;

    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: connectionTimeout,
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      // Drain any status bytes the printer sends back on disconnect.
      subscription = socket.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          LoggerService.warning(
            'Printer socket read error: $error',
            'NetworkPrinter',
          );
        },
      );

      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(sessionReleaseDelay);

      socket.destroy();
      destroyed = true;
      await socket.done;
    } on TimeoutException {
      throw const PrinterServiceException('Unable to connect to printer.');
    } on SocketException {
      throw const PrinterServiceException('Printer offline or network issue.');
    } catch (_) {
      throw const PrinterServiceException('Failed to send print job to printer.');
    } finally {
      await subscription?.cancel();
      if (!destroyed) {
        socket?.destroy();
      }
    }
  }
}

enum PrinterConnectivityStatus {
  unknown,
  checking,
  online,
  offline,
  notConfigured,
}

class PrinterConnectionState {
  final String? ipAddress;
  final PrinterConnectivityStatus status;

  const PrinterConnectionState({
    required this.ipAddress,
    required this.status,
  });

  bool get isConfigured => ipAddress != null && ipAddress!.isNotEmpty;
  bool get isOnline => status == PrinterConnectivityStatus.online;
}

class PrinterServiceException implements Exception {
  final String message;

  const PrinterServiceException(this.message);

  @override
  String toString() => message;
}

class DualPrintResult {
  final Object? kitchenError;
  final Object? billError;

  const DualPrintResult({
    required this.kitchenError,
    required this.billError,
  });

  bool get kitchenPrinted => kitchenError == null;
  bool get billPrinted => billError == null;
  bool get hasFailures => kitchenError != null || billError != null;
}

class BranchPrintConfig {
  final String name;
  final String address;
  final String phone;
  final String gstNumber;
  final bool hasPst;

  const BranchPrintConfig({
    required this.name,
    required this.address,
    required this.phone,
    required this.gstNumber,
    required this.hasPst,
  });
}

class PrinterService {
  static const Map<String, BranchPrintConfig> _branchConfigs = {
    'campbellriver': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Campbell River',
      address: '510 - 1400 Dogwood Street\nCampbell River, BC\nCanada, V9W 3A6',
      phone: '+1 7783462222',
      gstNumber: '771250156RT0001',
      hasPst: true,
    ),
    'canmore': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Canmore',
      address: '1310 Bow Valley Trail\nCanmore, AB\nCanada, T1W 1N6',
      phone: '+1 4036099997',
      gstNumber: '771254356RT0001',
      hasPst: false,
    ),
    'comox': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Comox',
      address: '1832 Comox Ave\nComox, BC\nCanada, V9M 3M7',
      phone: '+1 2509417444',
      gstNumber: '709021810RT0001',
      hasPst: true,
    ),
    'cranbrook': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Cranbrook',
      address: '1311 2 St N\nCranbrook, BC\nCanada, V1C 3L1',
      phone: '+1 2509417443',
      gstNumber: '',
      hasPst: true,
    ),
    'fortsaskatchewan': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Fort Saskatchewan',
      address: '9907 103 St\nFort Saskatchewan, AB\nCanada, T8L 2C8',
      phone: '+1 2507252005',
      gstNumber: '',
      hasPst: false,
    ),
    'ladysmith': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Ladysmith',
      address: '510 Esplanade Avenue\nLadysmith, BC\nCanada, V9G 1A9',
      phone: '+1 2509248222',
      gstNumber: '709024814RT0001',
      hasPst: true,
    ),
    'lloydminster': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Lloydminster',
      address: '4820 - 50th Avenue\nLloydminster, AB\nCanada, T9V 0W5',
      phone: '+1 7808754111',
      gstNumber: '7090214141RT0001',
      hasPst: false,
    ),
    'tofino': BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine - Tofino',
      address: '421 Main St #5\nTofino, BC\nCanada, V0R 2Z0',
      phone: '+1 2507252005',
      gstNumber: '',
      hasPst: true,
    ),
  };

  static BranchPrintConfig _resolveBranchConfig(String? branchId) {
    final key = (branchId ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _branchConfigs[key] ?? const BranchPrintConfig(
      name: 'Spice Hut Indian Cuisine',
      address: '',
      phone: '',
      gstNumber: '',
      hasPst: true,
    );
  }

  static String _formatDate(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final month = months[date.month - 1];
    final day = date.day;
    final year = date.year;
    
    int hour = date.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month $day, $year at $hour:$minute $ampm';
  }
  static const int _printerPort = 9100;
  static const Duration _healthTimeout = Duration(seconds: 2);
  static const int _maxAttempts = 2;
  static const PaperSize _paperSize = PaperSize.mm80;
  static const PrinterCommandMode _commandMode = PrinterCommandMode.escPos;

  static bool _initialized = false;
  static _PrinterLifecycleObserver? _lifecycleObserver;

  static final ValueNotifier<Map<PrinterRole, PrinterConnectionState>>
      connectionStateNotifier = ValueNotifier(
    {
      PrinterRole.kitchen: const PrinterConnectionState(
        ipAddress: null,
        status: PrinterConnectivityStatus.notConfigured,
      ),
      PrinterRole.bill: const PrinterConnectionState(
        ipAddress: null,
        status: PrinterConnectivityStatus.notConfigured,
      ),
    },
  );

  static bool get isAnyPrinterConfigured {
    return connectionStateNotifier.value.values.any((state) => state.isConfigured);
  }

  static PrinterConnectionState stateFor(PrinterRole role) {
    return connectionStateNotifier.value[role] ??
        const PrinterConnectionState(
          ipAddress: null,
          status: PrinterConnectivityStatus.unknown,
        );
  }

  static Future<void> initialize() async {
    if (_initialized) {
      await refreshConnectionState();
      return;
    }

    _initialized = true;
    _lifecycleObserver = _PrinterLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    await refreshConnectionState();
  }

  static Future<void> refreshConnectionState({String? branchId}) async {
    final resolvedBranch = await _resolveBranchId(branchId);
    final printerIps = await PrinterStorage.getPrinterIps(branchId: resolvedBranch);

    final kitchenIp = printerIps.kitchenIp;
    final billIp = printerIps.billIp;

    _setState(
      PrinterRole.kitchen,
      PrinterConnectionState(
        ipAddress: kitchenIp,
        status: kitchenIp == null
            ? PrinterConnectivityStatus.notConfigured
            : PrinterConnectivityStatus.checking,
      ),
    );
    _setState(
      PrinterRole.bill,
      PrinterConnectionState(
        ipAddress: billIp,
        status: billIp == null
            ? PrinterConnectivityStatus.notConfigured
            : PrinterConnectivityStatus.checking,
      ),
    );

    final kitchenReachableFuture = kitchenIp == null
        ? Future<bool>.value(false)
        : isPrinterReachable(kitchenIp, timeout: _healthTimeout);
    final billReachableFuture = billIp == null
        ? Future<bool>.value(false)
        : isPrinterReachable(billIp, timeout: _healthTimeout);

    final reachable = await Future.wait<bool>([
      kitchenReachableFuture,
      billReachableFuture,
    ]);

    _setState(
      PrinterRole.kitchen,
      PrinterConnectionState(
        ipAddress: kitchenIp,
        status: kitchenIp == null
            ? PrinterConnectivityStatus.notConfigured
            : (reachable[0]
                ? PrinterConnectivityStatus.online
                : PrinterConnectivityStatus.offline),
      ),
    );

    _setState(
      PrinterRole.bill,
      PrinterConnectionState(
        ipAddress: billIp,
        status: billIp == null
            ? PrinterConnectivityStatus.notConfigured
            : (reachable[1]
                ? PrinterConnectivityStatus.online
                : PrinterConnectivityStatus.offline),
      ),
    );
  }

  static Future<void> setKitchenPrinterIp(
    String ip, {
    String? branchId,
  }) async {
    final validationError = IpValidator.validateIpv4(
      ip,
      fieldName: 'Kitchen printer IP address',
    );
    if (validationError != null) {
      throw PrinterServiceException(validationError);
    }

    final resolvedBranch = await _resolveBranchId(branchId);
    await PrinterStorage.saveKitchenPrinterIp(ip, branchId: resolvedBranch);
    LoggerService.info(
      'Kitchen printer IP saved for ${resolvedBranch ?? 'default branch'}',
      'PrinterService',
    );

    await refreshConnectionState(branchId: resolvedBranch);
  }

  static Future<void> setBillPrinterIp(
    String ip, {
    String? branchId,
  }) async {
    final validationError = IpValidator.validateIpv4(
      ip,
      fieldName: 'Bill printer IP address',
    );
    if (validationError != null) {
      throw PrinterServiceException(validationError);
    }

    final resolvedBranch = await _resolveBranchId(branchId);
    await PrinterStorage.saveBillPrinterIp(ip, branchId: resolvedBranch);
    LoggerService.info(
      'Bill printer IP saved for ${resolvedBranch ?? 'default branch'}',
      'PrinterService',
    );

    await refreshConnectionState(branchId: resolvedBranch);
  }

  static Future<String?> getKitchenPrinterIp({String? branchId}) async {
    final resolvedBranch = await _resolveBranchId(branchId);
    return PrinterStorage.getKitchenPrinterIp(branchId: resolvedBranch);
  }

  static Future<String?> getBillPrinterIp({String? branchId}) async {
    final resolvedBranch = await _resolveBranchId(branchId);
    return PrinterStorage.getBillPrinterIp(branchId: resolvedBranch);
  }

  static Future<bool> hasKitchenPrinterConfigured({String? branchId}) async {
    final ip = await getKitchenPrinterIp(branchId: branchId);
    return ip != null && ip.isNotEmpty;
  }

  static Future<bool> hasBillPrinterConfigured({String? branchId}) async {
    final ip = await getBillPrinterIp(branchId: branchId);
    return ip != null && ip.isNotEmpty;
  }

  static Future<bool> isPrinterReachable(
    String ip, {
    Duration timeout = _healthTimeout,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, _printerPort, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  static Future<void> testKitchenPrinter({String? branchId}) async {
    final lines = <String>[
      'KITCHEN PRINTER TEST',
      '================================',
      'Connection successful',
      'Date: ${DateTime.now()}',
      '================================',
    ];

    await _printLines(
      role: PrinterRole.kitchen,
      lines: lines,
      branchId: branchId,
    );
  }

  static Future<void> testBillPrinter({String? branchId}) async {
    final lines = <String>[
      'BILL PRINTER TEST',
      '================================',
      'Connection successful',
      'Date: ${DateTime.now()}',
      '================================',
    ];

    await _printLines(
      role: PrinterRole.bill,
      lines: lines,
      branchId: branchId,
    );
  }

  static Future<DualPrintResult> printKitchenAndBillInParallel({
    required String orderId,
    required List<dynamic> items,
    required double totalAmount,
    String location = 'Main Kitchen',
    DateTime? orderTime,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? orderType,
    String? tableNumber,
    String? waiterName,
    String? branchId,
    double? tip,
  }) async {
    final kitchenResult = _captureError(
      printKitchenSlip(
        orderId,
        items,
        location: location,
        orderTime: orderTime,
        orderType: orderType,
        customerName: customerName,
        tableNumber: tableNumber,
        waiterName: waiterName,
        branchId: branchId,
      ),
    );
    final billResult = _captureError(
      printBillSlip(
        orderId,
        totalAmount,
        items: _normalizeItems(items),
        customerName: customerName,
        customerPhone: customerPhone,
        orderType: orderType,
        tableNumber: tableNumber,
        waiterName: waiterName,
        tip: tip,
        branchId: branchId,
      ),
    );

    final results = await Future.wait<Object?>([kitchenResult, billResult]);
    return DualPrintResult(
      kitchenError: results[0],
      billError: results[1],
    );
  }

  static Future<void> printKitchenSlip(
    String orderId,
    List<dynamic> items, {
    String location = 'Main Kitchen',
    DateTime? orderTime,
    String? orderType,
    String? customerName,
    String? tableNumber,
    String? waiterName,
    String? branchId,
  }) async {
    final config = _resolveBranchConfig(branchId);
    final dateStr = _formatDate(orderTime ?? DateTime.now());
    
    String orderTypeLine = '';
    if (orderType == 'table') {
      orderTypeLine = 'Table: $tableNumber';
    } else if (orderType == 'delivery' || orderType == 'takeaway' || orderType == 'pickup') {
      orderTypeLine = '${orderType![0].toUpperCase()}${orderType.substring(1)}: $customerName';
    }

    final staffLine = waiterName != null ? 'Staff: $waiterName' : '';

    final lines = <String>[
      '___BOLD___${config.name}',
      if (config.address.isNotEmpty) ...config.address.split('\n'),
      if (config.phone.isNotEmpty) 'Tel: ${config.phone}',
      'Printed $dateStr',
      '',
      '___LEFT_RIGHT___$dateStr|Order #:',
      '___LEFT_RIGHT___ |$orderId',
      if (orderTypeLine.isNotEmpty || staffLine.isNotEmpty) '___LEFT_RIGHT___$orderTypeLine|$staffLine',
      if (tableNumber != null && orderType != 'table') 'Table #: $tableNumber',
      if (config.gstNumber.isNotEmpty) 'GST #: ${config.gstNumber}',
      'Alcohol Tax #:',
      'Note:',
      '',
    ];

    if (customerName != null && customerName.isNotEmpty && orderType != 'table') {
      lines.addAll([
        '             CUSTOMER',
        '             $customerName',
      ]);
    }

    lines.addAll([
      '',
      '--------------------------------',
      'ITEMS:',
    ]);

    for (final item in items) {
      final name = _extractName(item);
      final qty = _extractQuantity(item);
      final spiceLevel = _extractSpiceLevel(item);
      
      lines.add('$qty x $name');
      if (spiceLevel != null && spiceLevel.isNotEmpty) {
        lines.add('  + $spiceLevel');
      }
    }

    lines.addAll([
      '--------------------------------',
    ]);

    await _printLines(
      role: PrinterRole.kitchen,
      lines: lines,
      branchId: branchId,
    );
  }

  static Future<void> printBillSlip(
    String orderId,
    double totalAmount, {
    List<Map<String, dynamic>>? items,
    String? customerName,
    String? customerPhone,
    String? orderType,
    String? tableNumber,
    String? waiterName,
    double? tip,
    String? branchId,
  }) async {
    final config = _resolveBranchConfig(branchId);
    final dateStr = _formatDate(DateTime.now());
    
    String orderTypeLine = '';
    if (orderType == 'table') {
      orderTypeLine = 'Table: $tableNumber';
    } else if (orderType == 'delivery' || orderType == 'takeaway' || orderType == 'pickup') {
      orderTypeLine = '${orderType![0].toUpperCase()}${orderType.substring(1)}: $customerName';
    }

    final staffLine = waiterName != null ? 'Staff: $waiterName' : '';

    final lines = <String>[
      '___BOLD___${config.name}',
      if (config.address.isNotEmpty) ...config.address.split('\n'),
      if (config.phone.isNotEmpty) 'Tel: ${config.phone}',
      'Printed $dateStr',
      '',
      '___LEFT_RIGHT___$dateStr|Order #:',
      '___LEFT_RIGHT___ |$orderId',
      if (orderTypeLine.isNotEmpty || staffLine.isNotEmpty) '___LEFT_RIGHT___$orderTypeLine|$staffLine',
      if (tableNumber != null && orderType != 'table') 'Table #: $tableNumber',
      if (config.gstNumber.isNotEmpty) 'GST #: ${config.gstNumber}',
      'Alcohol Tax #:',
      'Note:',
      '',
    ];

    if (customerName != null && customerName.isNotEmpty && orderType != 'table') {
      lines.addAll([
        '             CUSTOMER',
        '             $customerName',
        if (customerPhone != null && customerPhone.isNotEmpty) '             Tel:$customerPhone',
      ]);
    }
    
    lines.add('');

    double alcoholSubtotal = 0;
    double calculatedSubtotal = 0;

    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        final name = (item['name'] ?? 'Item').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final isAlcohol = item['isAlcohol'] == true;
        
        final itemTotal = qty * price;
        calculatedSubtotal += itemTotal;
        if (isAlcohol) {
          alcoholSubtotal += itemTotal;
        }

        final spiceLevel = _extractSpiceLevel(item);
        
        final priceStr = '\$${itemTotal.toStringAsFixed(2)}';
        final qtyName = qty > 1 ? '$qty x $name' : name;
        lines.add('___LEFT_RIGHT___$qtyName|$priceStr');
        
        if (spiceLevel != null && spiceLevel.isNotEmpty) {
          lines.add('  + $spiceLevel');
        }
      }
    } else {
      lines.add('See itemized details in app');
    }

    final subtotal = calculatedSubtotal > 0 ? calculatedSubtotal : totalAmount;
    final gstAmount = subtotal * 0.05;
    final pstAmount = config.hasPst ? (alcoholSubtotal * 0.10) : 0.0;
    final deliveryCharge = orderType == 'delivery' ? 5.0 : 0.0;
    
    final finalTotal = subtotal + gstAmount + pstAmount + deliveryCharge + (tip ?? 0);

    lines.addAll([
      '--------------------------------',
      '___LEFT_RIGHT___          Sub Total|\$${subtotal.toStringAsFixed(2)}',
      '___LEFT_RIGHT___          GST (5%)|\$${gstAmount.toStringAsFixed(2)}',
      '___LEFT_RIGHT___          Alcohol Tax|\$${pstAmount.toStringAsFixed(2)}',
    ]);
    
    if (deliveryCharge > 0) {
      lines.add('___LEFT_RIGHT___          Delivery|\$${deliveryCharge.toStringAsFixed(2)}');
    }
    if (tip != null && tip > 0) {
      lines.add('___LEFT_RIGHT___          Tip|\$${tip.toStringAsFixed(2)}');
    }

    lines.addAll([
      '--------------------------------',
      '___LEFT_RIGHT_BOLD___          Total|\$${finalTotal.toStringAsFixed(2)}',
      '',
      'Come Try The Taste Of India @ Spice Hut',
      '',
    ]);

    await _printLines(
      role: PrinterRole.bill,
      lines: lines,
      branchId: branchId,
    );
  }

  static Future<void> printAnalyticsSlip(
    List<String> lines, {
    String? branchId,
  }) async {
    final decorated = <String>[
      'ANALYTICS REPORT',
      '================================',
      ...lines,
      '================================',
      'Generated: ${DateTime.now()}',
    ];

    await _printLines(
      role: PrinterRole.bill,
      lines: decorated,
      branchId: branchId,
    );
  }

  static Future<void> _printLines({
    required PrinterRole role,
    required List<String> lines,
    String? branchId,
  }) async {
    final resolvedBranch = await _resolveBranchId(branchId);
    final bytes = await _buildPrintBytes(lines);

    String? primaryIp;
    try {
      primaryIp = await _resolvePrinterIp(role, resolvedBranch);
    } catch (_) {}

    if (primaryIp != null) {
      try {
        await _sendWithRetry(
          role: role,
          ip: primaryIp,
          bytes: bytes,
          branchId: resolvedBranch,
        );
        return;
      } catch (_) {
        // Fallback
      }
    }

    final fallbackRole = role == PrinterRole.kitchen ? PrinterRole.bill : PrinterRole.kitchen;
    String? fallbackIp;
    try {
      fallbackIp = await _resolvePrinterIp(fallbackRole, resolvedBranch);
    } catch (_) {}

    if (fallbackIp != null) {
      LoggerService.warning(
        '${role.name} printer unavailable. Falling back to ${fallbackRole.name} printer.',
        'PrinterService',
      );
      await _sendWithRetry(
        role: fallbackRole,
        ip: fallbackIp,
        bytes: bytes,
        branchId: resolvedBranch,
      );
      return;
    }

    throw PrinterServiceException(
      '${role.name} printer offline and no fallback printer available.',
    );
  }

  static Future<void> _sendWithRetry({
    required PrinterRole role,
    required String ip,
    required List<int> bytes,
    required String? branchId,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        await _sendToLan(ip, bytes);
        _setState(
          role,
          PrinterConnectionState(
            ipAddress: ip,
            status: PrinterConnectivityStatus.online,
          ),
        );
        return;
      } catch (error, stackTrace) {
        lastError = error;
        LoggerService.error(
          'Print attempt $attempt failed for ${role.name} printer at $ip',
          error,
          stackTrace,
          'PrinterService',
        );

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    _setState(
      role,
      PrinterConnectionState(
        ipAddress: ip,
        status: PrinterConnectivityStatus.offline,
      ),
    );

    if (lastError is PrinterServiceException) {
      throw lastError;
    }

    throw const PrinterServiceException('Failed to print. Please try again.');
  }

  static Future<void> _sendToLan(String ip, List<int> bytes) async {
    try {
      LoggerService.info(
        'Sending ${bytes.length} bytes to printer at $ip.',
        'PrinterService',
      );
      await NetworkPrinter.sendBytes(
        ip: ip,
        port: _printerPort,
        bytes: bytes,
      );
    } on TimeoutException {
      throw const PrinterServiceException('Unable to connect to printer.');
    } on SocketException {
      throw const PrinterServiceException('Printer offline or network issue.');
    } catch (_) {
      throw const PrinterServiceException('Failed to send print job to printer.');
    }
  }

  static Future<List<int>> _buildPrintBytes(List<String> lines) async {
    if (_commandMode == PrinterCommandMode.rawText) {
      return _buildRawTextBytes(lines);
    }

    return _buildEscPosBytes(lines);
  }

  static List<int> _buildRawTextBytes(List<String> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      buffer.write(line);
      buffer.write('\r\n');
    }
    buffer.write('\r\n\r\n');
    return latin1.encode(buffer.toString());
  }

  static Future<List<int>> _buildEscPosBytes(List<String> lines) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);

    final bytes = <int>[];
    bytes.addAll(generator.reset());

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        bytes.addAll(generator.emptyLines(1));
        continue;
      }

      if (RegExp(r'^[=]{8,}$').hasMatch(line) || RegExp(r'^[-]{8,}$').hasMatch(line)) {
        bytes.addAll(generator.hr(ch: '-')); // Use hyphens for all rules to match receipt
        continue;
      }

      if (line.startsWith('___BOLD___')) {
        bytes.addAll(
          generator.text(
            line.substring(10),
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
            ),
          ),
        );
        continue;
      }
      
      if (line.startsWith('___LEFT_RIGHT_BOLD___')) {
        final parts = line.substring(21).split('|');
        final left = parts[0];
        final right = parts.length > 1 ? parts[1] : '';
        bytes.addAll(generator.row([
          PosColumn(text: left, width: 8, styles: const PosStyles(bold: true)),
          PosColumn(text: right, width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]));
        continue;
      }

      if (line.startsWith('___LEFT_RIGHT___')) {
        final parts = line.substring(16).split('|');
        final left = parts[0];
        final right = parts.length > 1 ? parts[1] : '';
        bytes.addAll(generator.row([
          PosColumn(text: left, width: 8),
          PosColumn(text: right, width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]));
        continue;
      }

      // Default line formatting (centered)
      bytes.addAll(
        generator.text(
          line,
          styles: const PosStyles(
            align: PosAlign.center,
          ),
        ),
      );
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return bytes;
  }

  static Future<String?> _resolveBranchId(String? branchId) async {
    final normalized = branchId?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }

    return PrinterStorage.resolveActiveBranchId();
  }

  static Future<String> _resolvePrinterIp(
    PrinterRole role,
    String? branchId,
  ) async {
    final ip = role == PrinterRole.kitchen
        ? await PrinterStorage.getKitchenPrinterIp(branchId: branchId)
        : await PrinterStorage.getBillPrinterIp(branchId: branchId);

    if (ip == null || ip.isEmpty) {
      throw const PrinterServiceException(
        'Printer not configured. Please open Printer Setup.',
      );
    }

    return ip;
  }

  static Future<Object?> _captureError(Future<void> future) async {
    try {
      await future;
      return null;
    } catch (error) {
      return error;
    }
  }

  static List<Map<String, dynamic>> _normalizeItems(List<dynamic> items) {
    return items
        .map(
          (item) => {
            'name': _extractName(item),
            'quantity': _extractQuantity(item),
            'price': _extractPrice(item),
            'spiceLevel': _extractSpiceLevel(item),
            'isAlcohol': item is Map ? (item['isAlcohol'] == true) : false,
          },
        )
        .toList();
  }

  static String _extractName(dynamic item) {
    if (item is Map) {
      final value = item['name'] ?? item['title'];
      return value == null ? 'Item' : value.toString();
    }

    try {
      final dynamic dynamicItem = item;
      final dynamic name = dynamicItem.name;
      if (name != null) {
        return name.toString();
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return 'Item';
  }

  static int _extractQuantity(dynamic item) {
    if (item is Map) {
      final quantity = item['quantity'];
      if (quantity is num) {
        return quantity.toInt();
      }
    }

    try {
      final dynamic dynamicItem = item;
      final dynamic quantity = dynamicItem.quantity;
      if (quantity is num) {
        return quantity.toInt();
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return 1;
  }

  static double _extractPrice(dynamic item) {
    if (item is Map) {
      final price = item['price'];
      if (price is num) {
        return price.toDouble();
      }
    }

    try {
      final dynamic dynamicItem = item;
      final dynamic price = dynamicItem.price;
      if (price is num) {
        return price.toDouble();
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return 0;
  }

  static String? _extractSpiceLevel(dynamic item) {
    if (item is Map) {
      final value = item['spiceLevel'] ?? item['spice_level'];
      if (value != null) {
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }

    try {
      final dynamic dynamicItem = item;
      final dynamic value = dynamicItem.spiceLevel;
      if (value != null) {
        final trimmed = value.toString().trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return null;
  }

  static void _setState(PrinterRole role, PrinterConnectionState newState) {
    final updated =
        Map<PrinterRole, PrinterConnectionState>.from(connectionStateNotifier.value);
    updated[role] = newState;
    connectionStateNotifier.value = updated;
  }
}

class _PrinterLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PrinterService.refreshConnectionState());
    }
  }
}
