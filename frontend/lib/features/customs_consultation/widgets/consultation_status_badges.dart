import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class ConsultationStatusBadge extends StatelessWidget {
  final String status;

  const ConsultationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Color bg = AppTheme.textMuted;
    String displayStatus = status;

    if (status == 'Clearance Ready') {
      bg = AppTheme.emerald;
      displayStatus = l.statusClearanceReady;
    } else if (status == 'Blocked') {
      bg = AppTheme.crimson;
      displayStatus = l.statusBlocked;
    } else if (status == 'Action Required') {
      bg = AppTheme.orange;
      displayStatus = l.statusActionRequired;
    } else if (status == 'In Progress') {
      bg = AppTheme.cobalt;
      displayStatus = l.statusInProgress;
    } else if (status == 'Pending Review') {
      bg = AppTheme.wcagOrange;
      displayStatus = l.statusPendingReview;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(displayStatus, style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class ConsultationDocStatusBadge extends StatelessWidget {
  final String status;

  const ConsultationDocStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Color bg = AppTheme.textMuted;
    String displayStatus = status;

    if (status == 'Approved') {
      bg = AppTheme.emerald;
      displayStatus = l.statusApproved;
    } else if (status == 'Rejected') {
      bg = AppTheme.crimson;
      displayStatus = l.statusRejected;
    } else if (status == 'Verified') {
      bg = AppTheme.cobalt;
      displayStatus = l.statusVerified;
    } else if (status == 'Received') {
      bg = AppTheme.orange;
      displayStatus = l.statusReceived;
    } else if (status == 'Pending') {
      bg = AppTheme.textMuted;
      displayStatus = l.statusPending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(displayStatus, style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}
