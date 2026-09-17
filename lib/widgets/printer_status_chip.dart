import 'package:flutter/material.dart';

import '../services/printer_service.dart';

class PrinterStatusChip extends StatelessWidget {
  final List<PrinterRole> roles;

  const PrinterStatusChip({
    super.key,
    required this.roles,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<PrinterRole, PrinterConnectionState>>(
      valueListenable: PrinterService.connectionStateNotifier,
      builder: (_, states, __) {
        final summary = _summarize(states);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: summary.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.print, size: 14, color: summary.color),
              const SizedBox(width: 6),
              Text(
                summary.label,
                style: TextStyle(
                  color: summary.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _StatusSummary _summarize(Map<PrinterRole, PrinterConnectionState> states) {
    var anyNotConfigured = false;
    var anyChecking = false;
    var anyOffline = false;
    var allOnline = true;

    for (final role in roles) {
      final state = states[role] ?? PrinterService.stateFor(role);

      if (!state.isConfigured ||
          state.status == PrinterConnectivityStatus.notConfigured) {
        anyNotConfigured = true;
      }
      if (state.status == PrinterConnectivityStatus.checking) {
        anyChecking = true;
      }
      if (state.status == PrinterConnectivityStatus.offline) {
        anyOffline = true;
      }
      if (state.status != PrinterConnectivityStatus.online) {
        allOnline = false;
      }
    }

    if (anyNotConfigured) {
      return const _StatusSummary('Printer Not Set', Colors.grey);
    }
    if (anyChecking) {
      return const _StatusSummary('Printer Checking', Colors.blue);
    }
    if (anyOffline) {
      return const _StatusSummary('Printer Offline', Colors.red);
    }
    if (allOnline) {
      return const _StatusSummary('Printer Online', Color(0xFF2E7D32));
    }

    return const _StatusSummary('Printer Unknown', Colors.blueGrey);
  }
}

class _StatusSummary {
  final String label;
  final Color color;

  const _StatusSummary(this.label, this.color);
}
