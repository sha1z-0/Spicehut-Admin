import 'package:shared_preferences/shared_preferences.dart';

class PrinterIpConfig {
  final String? kitchenIp;
  final String? billIp;

  const PrinterIpConfig({
    required this.kitchenIp,
    required this.billIp,
  });
}

class PrinterStorage {
  static const String kitchenPrinterIpKey = 'kitchen_printer_ip';
  static const String billPrinterIpKey = 'bill_printer_ip';
  static const String _adminSelectedBranchKey = 'dashboard_selected_location';
  static const String _userBranchKey = 'user_location';
  static const Map<String, String> _branchAliases = {
    'nanaimo': 'fortsaskatchewan',
  };

  static Future<void> saveKitchenPrinterIp(
    String ip, {
    String? branchId,
  }) async {
    await _savePrinterIp(kitchenPrinterIpKey, ip, branchId: branchId);
  }

  static Future<void> saveBillPrinterIp(
    String ip, {
    String? branchId,
  }) async {
    await _savePrinterIp(billPrinterIpKey, ip, branchId: branchId);
  }

  static Future<String?> getKitchenPrinterIp({String? branchId}) {
    return _getPrinterIp(kitchenPrinterIpKey, branchId: branchId);
  }

  static Future<String?> getBillPrinterIp({String? branchId}) {
    return _getPrinterIp(billPrinterIpKey, branchId: branchId);
  }

  static Future<PrinterIpConfig> getPrinterIps({String? branchId}) async {
    final kitchenIp = await getKitchenPrinterIp(branchId: branchId);
    final billIp = await getBillPrinterIp(branchId: branchId);

    return PrinterIpConfig(kitchenIp: kitchenIp, billIp: billIp);
  }

  static Future<String?> resolveActiveBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_adminSelectedBranchKey)?.trim();
    if (selected != null && selected.isNotEmpty) {
      return selected;
    }

    final userLocation = prefs.getString(_userBranchKey)?.trim();
    if (userLocation != null && userLocation.isNotEmpty) {
      return userLocation;
    }

    return null;
  }

  static Future<void> _savePrinterIp(
    String baseKey,
    String ip, {
    String? branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedIp = ip.trim();

    final scopedKey = _scopedKey(baseKey, branchId);
    if (scopedKey != null) {
      await prefs.setString(scopedKey, normalizedIp);
      final legacyKey = _legacyScopedKey(baseKey, branchId);
      if (legacyKey != null && legacyKey != scopedKey) {
        await prefs.setString(legacyKey, normalizedIp);
      }
      return;
    }

    await prefs.setString(baseKey, normalizedIp);
  }

  static Future<String?> _getPrinterIp(
    String baseKey, {
    String? branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final scopedKey = _scopedKey(baseKey, branchId);
    if (scopedKey != null) {
      final scopedValue = prefs.getString(scopedKey)?.trim();
      if (scopedValue != null && scopedValue.isNotEmpty) {
        return scopedValue;
      }

      final legacyKey = _legacyScopedKey(baseKey, branchId);
      if (legacyKey != null) {
        final legacyValue = prefs.getString(legacyKey)?.trim();
        if (legacyValue != null && legacyValue.isNotEmpty) {
          await prefs.setString(scopedKey, legacyValue);
          return legacyValue;
        }
      }
    }

    final globalValue = prefs.getString(baseKey)?.trim();
    if (globalValue == null || globalValue.isEmpty) {
      return null;
    }

    return globalValue;
  }

  static String? _scopedKey(String baseKey, String? branchId) {
    final normalized = branchId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return '${baseKey}_${_sanitizeBranchId(normalized)}';
  }

  static String? _legacyScopedKey(String baseKey, String? branchId) {
    final normalized = branchId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return '${baseKey}_${_legacySanitizeBranchId(normalized)}';
  }

  static String _sanitizeBranchId(String branchId) {
    final cleaned = branchId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final mapped = _branchAliases[cleaned] ?? cleaned;
    return mapped.isEmpty ? 'default' : mapped;
  }

  static String _legacySanitizeBranchId(String branchId) {
    final sanitized = branchId
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return sanitized.isEmpty ? 'default' : sanitized;
  }
}
