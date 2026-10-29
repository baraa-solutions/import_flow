import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// ⏱️ Import Requirements Lifecycle Stepper — ImportFlow ERP
///
/// Visualizes the operational milestones from ACID issuance,
/// pre-shipment inspection, statutory certificates, and sailing clearance.
class ImportRequirementsLifecycleStepper extends StatelessWidget {
  final String sailingStatus;
  final String acidNumber;
  final String inspectionStatus;
  final String cooStatus;
  final bool whiteListVerified;

  const ImportRequirementsLifecycleStepper({
    super.key,
    required this.sailingStatus,
    required this.acidNumber,
    required this.inspectionStatus,
    required this.cooStatus,
    required this.whiteListVerified,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Obtained':
      case 'Completed':
      case 'Approved':
      case 'Cleared':
      case 'Confirmed':
      case 'Cleared for Sailing':
      case 'Sailed':
        return AppTheme.emerald;
      case 'Pending':
      case 'In Progress':
      case 'Applied':
      case 'Scheduled':
      case 'Pre-Sailing':
        return AppTheme.orange;
      case 'Rejected':
        return AppTheme.crimson;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = _getStatusColor(sailingStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.requirementsLifecycleCardTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  l10n.sailingStatusBadge(sailingStatus),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStepNode(
                step: '1',
                title: l10n.acidIssuanceStep,
                subtitle: acidNumber.isNotEmpty ? acidNumber : l10n.acidIssuedInPhaseText,
                isCompleted: acidNumber.isNotEmpty,
                isActive: true,
              ),
              _buildStepConnector(isCompleted: acidNumber.isNotEmpty),
              _buildStepNode(
                step: '2',
                title: l10n.preShipmentInspectionStep,
                subtitle: inspectionStatus == 'Completed'
                    ? l10n.completedAndPassedInspection
                    : l10n.pendingInspectionCoordination,
                isCompleted: inspectionStatus == 'Completed',
                isActive: true,
              ),
              _buildStepConnector(isCompleted: inspectionStatus == 'Completed'),
              _buildStepNode(
                step: '3',
                title: l10n.approvalsAndCertsStep,
                subtitle: cooStatus == 'Obtained' && whiteListVerified
                    ? l10n.allCertsFulfilled100
                    : l10n.pendingApprovals,
                isCompleted: cooStatus == 'Obtained' && whiteListVerified,
                isActive: true,
              ),
              _buildStepConnector(
                isCompleted: sailingStatus == 'Cleared for Sailing' || sailingStatus == 'Sailed',
              ),
              _buildStepNode(
                step: '4',
                title: l10n.sailingClearanceStep,
                subtitle: sailingStatus,
                isCompleted: sailingStatus == 'Cleared for Sailing' || sailingStatus == 'Sailed',
                isActive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required String step,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    final color = isCompleted ? AppTheme.emerald : (isActive ? AppTheme.cobalt : AppTheme.textMuted);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color,
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: AppTheme.white)
                  : Text(step, style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textStrong),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Container(
      width: 16,
      height: 2,
      color: isCompleted ? AppTheme.emerald : AppTheme.cloudWhite,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
