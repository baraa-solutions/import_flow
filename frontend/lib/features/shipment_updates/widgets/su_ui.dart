import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/customs_ui.dart';

/// Shared look of the shipment-updates screen and dialogs (tokens from [AppTheme] only).
class SuUi {
  SuUi._();

  /// Update category -> chip severity.
  static AppSeverity categorySeverity(String category) {
    switch (category) {
      case 'Daily Check-in':
        return AppSeverity.success;
      case 'Phase Cost Adjustment':
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }

  /// Pipeline phase status -> severity.
  static AppSeverity phaseSeverity(String status) {
    switch (status) {
      case 'Completed':
        return AppSeverity.success;
      case 'Current':
        return AppSeverity.info;
      default:
        return AppSeverity.warning;
    }
  }

  static IconData phaseIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Current':
        return Icons.play_circle_fill;
      default:
        return Icons.upcoming;
    }
  }

  /// Customs consultation overall status -> severity.
  static AppSeverity consultationSeverity(String status) {
    switch (status) {
      case 'Clearance Ready':
      case 'Completed':
        return AppSeverity.success;
      case 'Blocked':
        return AppSeverity.danger;
      case 'Action Required':
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }

  /// Checklist document status -> severity.
  static AppSeverity docStatusSeverity(String status) {
    switch (status) {
      case 'Approved':
        return AppSeverity.success;
      case 'Rejected':
        return AppSeverity.danger;
      case 'Received':
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }

  /// Readiness percentage -> severity (>= 80 good, >= 50 caution, else bad).
  static AppSeverity readinessSeverity(double pct) {
    if (pct >= 80) return AppSeverity.success;
    if (pct >= 50) return AppSeverity.warning;
    return AppSeverity.danger;
  }

  static String customsStatusLabel(AppLocalizations l, String status) {
    switch (status) {
      case 'In Progress':
        return l.shipmentUpdateConsultStatusInProgress;
      case 'Clearance Ready':
        return l.shipmentUpdateConsultStatusClearanceReady;
      case 'Blocked':
        return l.shipmentUpdateConsultStatusBlocked;
      case 'Action Required':
        return l.shipmentUpdateConsultStatusActionRequired;
      case 'Completed':
        return l.shipmentUpdateConsultStatusCompleted;
      default:
        return status;
    }
  }

  static String docStatusLabel(AppLocalizations l, String status) {
    switch (status) {
      case 'Approved':
        return l.shipmentUpdateDocStatusApproved;
      case 'Pending':
        return l.shipmentUpdateDocStatusPending;
      case 'Received':
        return l.shipmentUpdateDocStatusReceived;
      case 'Verified':
        return l.shipmentUpdateDocStatusVerified;
      case 'Rejected':
        return l.shipmentUpdateDocStatusRejected;
      default:
        return status;
    }
  }
}

/// Small tinted tile: caption + value, coloured by severity.
class SuMetricBadge extends StatelessWidget {
  const SuMetricBadge({super.key, required this.title, required this.value, required this.severity});

  final String title;
  final String value;
  final AppSeverity severity;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          LtrText(value, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Copyable cobalt code pill (update code / consultation code).
class SuCodeBadge extends StatelessWidget {
  const SuCodeBadge({super.key, required this.code, required this.copiedMessage, this.fontSize = 12});

  final String code;
  final String copiedMessage;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, code, customMessage: copiedMessage),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.cobaltLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.cobaltBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy_rounded, size: 12, color: AppTheme.cobalt),
            const SizedBox(width: 4),
            LtrText(code, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: fontSize)),
          ],
        ),
      ),
    );
  }
}

/// One tile of the 10-phase pipeline (status chip colours come from severity).
class SuPhaseTile extends StatelessWidget {
  const SuPhaseTile({
    super.key,
    required this.name,
    required this.statusLabel,
    required this.status,
    required this.countLabel,
    required this.onTap,
  });

  final String name;
  final String statusLabel;
  final String status;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sev = SuUi.phaseSeverity(status);
    final fg = AppTheme.severityForegroundOf(context, sev);
    final bg = AppTheme.severityBackgroundOf(context, sev);
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 10),
      width: 148,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsetsDirectional.all(10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: fg.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(SuUi.phaseIcon(status), size: 16, color: fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimaryOf(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                countLabel,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status chip for a customs-consultation overall status.
class SuConsultationStatusChip extends StatelessWidget {
  const SuConsultationStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => CcStatusChip(
        label: SuUi.customsStatusLabel(context.l10n, status),
        severity: SuUi.consultationSeverity(status),
      );
}

/// Status chip for a checklist document status.
class SuDocStatusChip extends StatelessWidget {
  const SuDocStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => CcStatusChip(
        label: SuUi.docStatusLabel(context.l10n, status),
        severity: SuUi.docStatusSeverity(status),
      );
}
