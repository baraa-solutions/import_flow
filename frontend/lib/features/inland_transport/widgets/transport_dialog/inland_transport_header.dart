import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../import_files/models/import_file_model.dart';

/// Booking statuses written by the backend and domain enums.
class InlandStatus {
  InlandStatus._();
  static const bookingConfirmed = 'BOOKING_CONFIRMED';
  static const dispatched = 'DISPATCHED';
  static const inTransit = 'IN_TRANSIT';
  static const arrived = 'ARRIVED_AT_WAREHOUSE';
  static const delivered = 'DELIVERED';
  static const cancelled = 'CANCELLED';

  static String codeOf(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return DomainEnums.legacyToCode(DomainEnumType.inlandTransportStatus, raw.trim()) ?? raw.trim();
  }

  static bool isArrivedOrDelivered(String? raw) {
    final code = codeOf(raw);
    return code == arrived || code == delivered;
  }

  static bool isInTransit(String? raw) {
    final code = codeOf(raw);
    return code == inTransit;
  }

  static bool isBookingConfirmedOrDispatched(String? raw) {
    final code = codeOf(raw);
    return code == bookingConfirmed || code == dispatched;
  }

  static AppSeverity severity(String? status) {
    final code = codeOf(status);
    switch (code) {
      case arrived:
      case delivered:
        return AppSeverity.success;
      case inTransit:
        return AppSeverity.info;
      case bookingConfirmed:
      case dispatched:
        return AppSeverity.warning;
      case cancelled:
        return AppSeverity.danger;
      default:
        return AppSeverity.info;
    }
  }

  static Color color(String? status) {
    final code = codeOf(status);
    switch (code) {
      case arrived:
      case delivered:
        return AppTheme.emerald;
      case inTransit:
        return AppTheme.cobalt;
      case bookingConfirmed:
      case dispatched:
        return AppTheme.flatOrange;
      case cancelled:
        return AppTheme.crimson;
      default:
        return AppTheme.charcoal;
    }
  }

  static String label(AppLocalizations l10n, String? status) {
    if (status == null || status.trim().isEmpty) return l10n.inlandStatusNotBooked;
    final code = codeOf(status);
    if (DomainEnums.isCode(DomainEnumType.inlandTransportStatus, code)) {
      return DomainEnums.label(l10n, DomainEnumType.inlandTransportStatus, code);
    }
    return status;
  }
}

/// Header bar of the Inland Transport Coordination dialog.
class InlandTransportHeader extends StatelessWidget {
  final ImportFileModel file;
  final String? status;
  final VoidCallback onClose;

  const InlandTransportHeader({
    super.key,
    required this.file,
    required this.status,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: AppTheme.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inlandDialogTitle,
                  style: const TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.inlandDialogFileLine(file.primaryNameWithCode, file.companyName),
                        style: TextStyle(color: AppTheme.white.withAlpha(180), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: InlandStatus.label(l10n, status),
                      severity: InlandStatus.severity(status),
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.cloudWhite.withAlpha(180)),
            onPressed: onClose,
            tooltip: l10n.inlandCloseTooltip,
          ),
        ],
      ),
    );
  }
}
