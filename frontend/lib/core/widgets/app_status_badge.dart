import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 🏷️ Unified Status Badge — ImportFlow ERP
///
/// Replaces the 420+ manual `Container(decoration: BoxDecoration(...))` status
/// badge implementations spread across 146 files.
///
/// Usage:
/// ```dart
/// // Simple severity-based badge
/// AppStatusBadge(label: 'نشط', severity: AppSeverity.success)
/// AppStatusBadge(label: 'مُعلَّق', severity: AppSeverity.warning)
/// AppStatusBadge(label: 'مُلغى', severity: AppSeverity.danger)
/// AppStatusBadge(label: 'جديد', severity: AppSeverity.info)
///
/// // Auto-resolve from string status key
/// AppStatusBadge.fromStatus(status: 'ACTIVE', label: l10n.active)
/// AppStatusBadge.fromStatus(status: 'CLOSED')
/// ```
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppSeverity severity;
  final AppStatusBadgeSize size;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.severity,
    this.size = AppStatusBadgeSize.medium,
    this.icon,
  });

  /// Auto-resolves severity from a standard status string key.
  ///
  /// Recognised success keys: ACTIVE, APPROVED, COMPLETED, DONE, MATCH,
  ///   PAID, RELEASED, CLEARED, DELIVERED, RECEIVED, OPEN (for open docs),
  ///   VALID, CONFIRMED, YES, TRUE, PASS.
  ///
  /// Recognised warning keys: PENDING, IN_PROGRESS, PROCESSING, PARTIAL,
  ///   WARNING, DRAFT, HOLD, REVIEW, ON_HOLD, WAITING, SCHEDULED, SUBMITTED.
  ///
  /// Recognised danger keys: REJECTED, CANCELLED, EXPIRED, OVERDUE, FAILED,
  ///   ERROR, INACTIVE, DELETED, CLOSED (for files), NO, FALSE, MISMATCH.
  ///
  /// Everything else → info.
  factory AppStatusBadge.fromStatus({
    Key? key,
    required String status,
    String? label,
    AppStatusBadgeSize size = AppStatusBadgeSize.medium,
    IconData? icon,
  }) {
    final upper = status.toUpperCase();
    final severity = _resolveStatusSeverity(upper);
    return AppStatusBadge(
      key: key,
      label: label ?? status,
      severity: severity,
      size: size,
      icon: icon,
    );
  }

  static AppSeverity _resolveStatusSeverity(String upper) {
    const successKeys = {
      'ACTIVE', 'APPROVED', 'COMPLETED', 'DONE', 'MATCH', 'PAID',
      'RELEASED', 'CLEARED', 'DELIVERED', 'RECEIVED', 'VALID', 'CONFIRMED',
      'YES', 'TRUE', 'PASS', 'SUCCESS', 'ACCEPTED', 'VERIFIED', 'COLLECTED',
      'SETTLED', 'REGISTERED', 'FINALIZED', 'OPEN',
    };
    const warningKeys = {
      'PENDING', 'IN_PROGRESS', 'PROCESSING', 'PARTIAL', 'WARNING', 'DRAFT',
      'HOLD', 'REVIEW', 'ON_HOLD', 'WAITING', 'SCHEDULED', 'SUBMITTED',
      'UNDER_REVIEW', 'AMENDED', 'UNDER_INSPECTION', 'SAMPLE_TAKEN',
    };
    const dangerKeys = {
      'REJECTED', 'CANCELLED', 'EXPIRED', 'OVERDUE', 'FAILED', 'ERROR',
      'INACTIVE', 'DELETED', 'CLOSED', 'NO', 'FALSE', 'MISMATCH',
      'BLOCKED', 'SUSPENDED', 'DEACTIVATED', 'LOST', 'DAMAGED',
    };

    if (successKeys.contains(upper)) return AppSeverity.success;
    if (warningKeys.contains(upper)) return AppSeverity.warning;
    if (dangerKeys.contains(upper)) return AppSeverity.danger;
    return AppSeverity.info;
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.severityBackgroundOf(context, severity);
    final fg = AppTheme.severityForegroundOf(context, severity);

    final (hPad, vPad, fontSize) = switch (size) {
      AppStatusBadgeSize.small  => (6.0, 2.0, 10.0),
      AppStatusBadgeSize.medium => (8.0, 3.0, 11.0),
      AppStatusBadgeSize.large  => (12.0, 5.0, 12.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: fg.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: fg),
            SizedBox(width: hPad / 2),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Size variants for [AppStatusBadge].
enum AppStatusBadgeSize { small, medium, large }
