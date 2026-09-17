import 'package:flutter/material.dart';

import '../services/logger_service.dart';
import '../services/printer_service.dart';
import '../storage/printer_storage.dart';
import '../utils/ip_validator.dart';

class PrinterSetupGuideModal extends StatefulWidget {
  const PrinterSetupGuideModal({super.key});

  @override
  State<PrinterSetupGuideModal> createState() => _PrinterSetupGuideModalState();
}

class _PrinterSetupGuideModalState extends State<PrinterSetupGuideModal> {
  static const Color _accentOrange = Color(0xFFFF7A00);
  static const Color _accentOrangeDark = Color(0xFFE56E00);
  static const Color _accentOrangeSoft = Color(0xFFFFF1E6);

  bool _isLoading = true;
  bool _isRefreshingStatus = false;
  bool _isSavingKitchen = false;
  bool _isSavingBill = false;
  bool _isTestingKitchen = false;
  bool _isTestingBill = false;

  String? _branchId;
  String? _kitchenIp;
  String? _billIp;
  PrinterRole? _editingRole;
  String? _ipEditorError;
  late final TextEditingController _ipEditorController;

  @override
  void initState() {
    super.initState();
    _ipEditorController = TextEditingController();
    _loadPrinterConfiguration();
  }

  @override
  void dispose() {
    _ipEditorController.dispose();
    super.dispose();
  }

  Future<void> _loadPrinterConfiguration({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    final resolvedBranch = await PrinterStorage.resolveActiveBranchId();
    final branchId = resolvedBranch ?? _branchId;
    await PrinterService.refreshConnectionState(branchId: branchId);

    final kitchenIp = await PrinterService.getKitchenPrinterIp(branchId: branchId);
    final billIp = await PrinterService.getBillPrinterIp(branchId: branchId);

    if (!mounted) return;

    setState(() {
      _branchId = branchId;
      _kitchenIp = kitchenIp;
      _billIp = billIp;
      _isLoading = false;
      _isRefreshingStatus = false;
    });
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshingStatus = true);
    await _loadPrinterConfiguration(showLoader: false);
  }

  void _configureKitchenPrinter() {
    _openIpEditor(PrinterRole.kitchen);
  }

  void _configureBillPrinter() {
    _openIpEditor(PrinterRole.bill);
  }

  void _openIpEditor(PrinterRole role) {
    final initialIp = role == PrinterRole.kitchen ? _kitchenIp : _billIp;

    setState(() {
      _editingRole = role;
      _ipEditorError = null;
      _ipEditorController.text = initialIp ?? '';
      _ipEditorController.selection = TextSelection.fromPosition(
        TextPosition(offset: _ipEditorController.text.length),
      );
    });
  }

  void _closeIpEditor() {
    if (!mounted) return;
    setState(() {
      _editingRole = null;
      _ipEditorError = null;
    });
  }

  Future<void> _saveIpFromEditor() async {
    final role = _editingRole;
    if (role == null) return;

    final fieldName = role == PrinterRole.kitchen
        ? 'Kitchen printer IP address'
        : 'Bill slip printer IP address';

    final input = _ipEditorController.text.trim();
    final validationError = IpValidator.validateIpv4(
      input,
      fieldName: fieldName,
    );

    if (validationError != null) {
      setState(() => _ipEditorError = validationError);
      return;
    }

    await _savePrinterIp(role: role, ip: input);

    if (!mounted) return;
    _closeIpEditor();
  }

  Future<void> _savePrinterIp({
    required PrinterRole role,
    required String ip,
  }) async {
    setState(() {
      if (role == PrinterRole.kitchen) {
        _isSavingKitchen = true;
      } else {
        _isSavingBill = true;
      }
    });

    final shouldWarnDuplicate = role == PrinterRole.kitchen
        ? _billIp == ip
        : _kitchenIp == ip;

    try {
      if (role == PrinterRole.kitchen) {
        await PrinterService.setKitchenPrinterIp(ip, branchId: _branchId);
      } else {
        await PrinterService.setBillPrinterIp(ip, branchId: _branchId);
      }

      await _loadPrinterConfiguration(showLoader: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            role == PrinterRole.kitchen
                ? 'Kitchen printer IP saved successfully.'
                : 'Bill printer IP saved successfully.',
          ),
          backgroundColor: _accentOrange,
        ),
      );

      if (shouldWarnDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Warning: Both printers are set to the same IP address.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (role == PrinterRole.kitchen) {
            _isSavingKitchen = false;
          } else {
            _isSavingBill = false;
          }
        });
      }
    }
  }

  Future<void> _testKitchenPrinter() async {
    setState(() => _isTestingKitchen = true);

    try {
      final branchId = await PrinterStorage.resolveActiveBranchId() ?? _branchId;
      final ip = await PrinterService.getKitchenPrinterIp(branchId: branchId);
      if (ip == null || ip.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kitchen printer not configured.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        LoggerService.warning(
          'Kitchen test print skipped: no IP configured.',
          'PrinterSetup',
        );
        return;
      }

      LoggerService.info(
        'Kitchen test print requested for ${branchId ?? 'default'} ($ip).',
        'PrinterSetup',
      );
      await PrinterService.testKitchenPrinter(branchId: branchId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kitchen test print sent successfully.'),
          backgroundColor: _accentOrange,
        ),
      );
      await _loadPrinterConfiguration(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      LoggerService.error(
        'Kitchen test print failed',
        error,
        null,
        'PrinterSetup',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTestingKitchen = false);
      }
    }
  }

  Future<void> _testBillPrinter() async {
    setState(() => _isTestingBill = true);

    try {
      final branchId = await PrinterStorage.resolveActiveBranchId() ?? _branchId;
      final ip = await PrinterService.getBillPrinterIp(branchId: branchId);
      if (ip == null || ip.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill printer not configured.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        LoggerService.warning(
          'Bill test print skipped: no IP configured.',
          'PrinterSetup',
        );
        return;
      }

      LoggerService.info(
        'Bill test print requested for ${branchId ?? 'default'} ($ip).',
        'PrinterSetup',
      );
      await PrinterService.testBillPrinter(branchId: branchId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printer test print sent successfully.'),
          backgroundColor: _accentOrange,
        ),
      );
      await _loadPrinterConfiguration(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      LoggerService.error(
        'Bill test print failed',
        error,
        null,
        'PrinterSetup',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTestingBill = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditorVisible = _editingRole != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: ValueListenableBuilder<
                            Map<PrinterRole, PrinterConnectionState>>(
                          valueListenable: PrinterService.connectionStateNotifier,
                          builder: (_, __, ___) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 640;
                                final cardWidth = isWide
                                    ? (constraints.maxWidth - 16) / 2
                                    : constraints.maxWidth;

                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildPrinterCard(
                                        role: PrinterRole.kitchen,
                                        title: 'Kitchen Printer',
                                        subtitle:
                                            'Used for kitchen preparation slips',
                                        icon: Icons.restaurant_menu,
                                        ipAddress: _kitchenIp,
                                        isSaving: _isSavingKitchen,
                                        isTesting: _isTestingKitchen,
                                        onConfigure: _configureKitchenPrinter,
                                        onTest: _testKitchenPrinter,
                                        buttonLabel: 'Configure Kitchen Printer',
                                      ),
                                    ),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _buildPrinterCard(
                                        role: PrinterRole.bill,
                                        title: 'Bill Slip Printer',
                                        subtitle:
                                            'Used for customer bills and reports',
                                        icon: Icons.receipt_long,
                                        ipAddress: _billIp,
                                        isSaving: _isSavingBill,
                                        isTesting: _isTestingBill,
                                        onConfigure: _configureBillPrinter,
                                        onTest: _testBillPrinter,
                                        buttonLabel: 'Configure Bill Slip Printer',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
              ),
            ),
            if (isEditorVisible) _buildCenteredIpEditor(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredIpEditor(BuildContext context) {
    final role = _editingRole;
    if (role == null) {
      return const SizedBox.shrink();
    }

    final title = role == PrinterRole.kitchen
        ? 'Enter Kitchen Printer IP Address'
        : 'Enter Bill Slip Printer IP Address';
    final hint = role == PrinterRole.kitchen ? '192.168.1.50' : '192.168.1.51';
    final isSaving = role == PrinterRole.kitchen ? _isSavingKitchen : _isSavingBill;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ipEditorController,
                          autofocus: true,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: hint,
                            errorText: _ipEditorError,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving ? null : _closeIpEditor,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentOrange,
                                ),
                                onPressed: isSaving ? null : _saveIpFromEditor,
                                child: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Save',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentOrange,
            _accentOrangeDark,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.print_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Printer Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _branchId == null
                      ? 'Default network profile'
                      : 'Branch profile: $_branchId',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard({
    required PrinterRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required String? ipAddress,
    required bool isSaving,
    required bool isTesting,
    required VoidCallback onConfigure,
    required VoidCallback onTest,
    required String buttonLabel,
  }) {
    final state = PrinterService.stateFor(role);
    final hasIp = ipAddress != null && ipAddress.isNotEmpty;
    final ipText = ipAddress ?? 'Not configured';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  color: _accentOrangeSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accentOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(state),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF5F7FA),
            ),
            child: Text(
              ipText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hasIp ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onConfigure,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.edit_outlined),
              label: Text(buttonLabel),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (!hasIp || isTesting) ? null : onTest,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _accentOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                foregroundColor: _accentOrange,
              ),
              icon: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('Test Print'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PrinterConnectionState state) {
    final color = _statusColor(state);
    final label = _statusLabel(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isRefreshingStatus ? null : _refreshStatus,
            icon: _isRefreshingStatus
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Refresh Status'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  String _statusLabel(PrinterConnectionState state) {
    switch (state.status) {
      case PrinterConnectivityStatus.online:
        return 'Online';
      case PrinterConnectivityStatus.offline:
        return 'Offline';
      case PrinterConnectivityStatus.checking:
        return 'Checking';
      case PrinterConnectivityStatus.notConfigured:
        return 'Not Set';
      case PrinterConnectivityStatus.unknown:
        return state.isConfigured ? 'Unknown' : 'Not Set';
    }
  }

  Color _statusColor(PrinterConnectionState state) {
    switch (state.status) {
      case PrinterConnectivityStatus.online:
        return _accentOrange;
      case PrinterConnectivityStatus.offline:
        return Colors.red;
      case PrinterConnectivityStatus.checking:
        return Colors.blue;
      case PrinterConnectivityStatus.notConfigured:
        return Colors.grey;
      case PrinterConnectivityStatus.unknown:
        return state.isConfigured ? Colors.blueGrey : Colors.grey;
    }
  }
}
