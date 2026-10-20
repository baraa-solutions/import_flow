import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Pure mapping from the demurrage statuses the backend sends to the shared
/// severity scale (success / warning / danger / info) so the whole feature
/// colours exposure the same way.
class DemurrageStatusStyle {
  DemurrageStatusStyle._();

  /// Tracking status ("Free Time Active", "Demurrage Incurred", ...).
  static AppSeverity ofTracking(String status) {
    final s = status.trim();
    if (s.contains('Incurred') || s == 'CRITICAL_OVERDUE') return AppSeverity.danger;
    if (s == 'Pushed to Settlement') return AppSeverity.info;
    if (s.contains('Warning') || s == 'WARNING') return AppSeverity.warning;
    if (s == 'RETURNED_SAFE' || s == 'Closed' || s == 'Free Time Active' || s == 'SAFE') {
      return AppSeverity.success;
    }
    return AppSeverity.info;
  }

  /// Simulation / radar badge ("SAFE", "WARNING", "*_INCURRED", ...).
  static AppSeverity ofBadge(String badge) {
    switch (badge) {
      case 'SAFE':
        return AppSeverity.success;
      case 'WARNING':
      case 'STORAGE_WARNING_48H':
        return AppSeverity.warning;
      default:
        return AppSeverity.danger;
    }
  }

  static IconData iconOf(AppSeverity severity) {
    switch (severity) {
      case AppSeverity.success:
        return Icons.check_circle_outline;
      case AppSeverity.warning:
        return Icons.hourglass_bottom_rounded;
      case AppSeverity.danger:
        return Icons.warning_amber_rounded;
      case AppSeverity.info:
        return Icons.info_outline;
    }
  }

  /// A container is closed out (returned or fully settled): no accruing clock.
  static bool isReturned(String status) => status == 'RETURNED_SAFE' || status == 'Closed';

  /// Whole days between discharge and gate-out (or [now] while still in port).
  static int daysSinceDischarge(String dischargeDate, String? gateOutDate, {DateTime? now}) {
    final start = DateTime.tryParse(dischargeDate);
    if (start == null) return 0;
    final end = (gateOutDate != null ? DateTime.tryParse(gateOutDate) : null) ?? (now ?? DateTime.now());
    final days = end.difference(start).inDays;
    return days < 0 ? 0 : days;
  }
}
