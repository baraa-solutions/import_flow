import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_requirement_model.dart';
import '../governance/maker_checker_dialog.dart';

/// 📋 Requirement Details Dialog — ImportFlow ERP
///
/// Comprehensive modal viewer displaying full assessment metadata,
/// statutory 5 Pillars status, advanced pillars parameters,
/// and maker-checker dual-control governance trails.
class RequirementDetailsDialog extends StatelessWidget {
  final ImportRequirementModel requirement;
  final ValueChanged<ImportRequirementModel>? onRequirementUpdated;

  const RequirementDetailsDialog({
    super.key,
    required this.requirement,
    this.onRequirementUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ImportRequirementModel requirement,
    ValueChanged<ImportRequirementModel>? onRequirementUpdated,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RequirementDetailsDialog(
        requirement: requirement,
        onRequirementUpdated: onRequirementUpdated,
      ),
    );
  }

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
      case 'Waived':
        return AppTheme.cobalt;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getRiskLevelColor(String risk) {
    switch (risk) {
      case 'Low':
      case 'منخفض':
        return AppTheme.emerald;
      case 'Medium':
      case 'متوسط':
        return AppTheme.orange;
      case 'High':
      case 'مرتفع':
        return AppTheme.crimson;
      default:
        return AppTheme.textMuted;
    }
  }

  String _buildRequirementSummary(AppLocalizations l10n, ImportRequirementModel req) {
    return '${req.assessmentCode} | ${req.importFileCode ?? ""} | ${req.hsCode ?? ""} | '
        '${req.commodityDescription ?? ""} | ${req.shipmentValue.toStringAsFixed(2)} ${req.currency ?? ""} | '
        '${req.supplierName ?? ""} | ${req.overallStatus} | ${req.riskLevel}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = requirement;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.fact_check_outlined, color: AppTheme.cobalt, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.requirementDetailsDialogTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildCopyableBadge(context, req.assessmentCode, AppTheme.cobalt, l10n.copyAssessmentCodeTooltip),
                    if (req.importFileCode != null && req.importFileCode!.isNotEmpty)
                      _buildCopyableBadge(context, req.importFileCode!, AppTheme.charcoal, l10n.colImportFile),
                    if (req.acidNumber != null && req.acidNumber!.isNotEmpty)
                      _buildCopyableBadge(context, req.acidNumber!, AppTheme.emerald, l10n.copyAcidNumberTooltip),
                    _buildBadge(req.overallStatus, _getStatusColor(req.overallStatus)),
                    _buildBadge(req.riskLevel, _getRiskLevelColor(req.riskLevel)),
                    if (req.isOverridden)
                      _buildBadge(l10n.checkerStatusOverriddenBadge, AppTheme.orange)
                    else if (req.checkerApproved)
                      _buildBadge(l10n.checkerStatusApprovedBadge, AppTheme.emerald)
                    else
                      _buildBadge(l10n.checkerStatusPendingBadge, AppTheme.charcoal),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Core Metadata
                _buildSectionHeader(l10n.makerSectionTitle),
                const SizedBox(height: 8),
                _buildDetailRow(l10n.hsCodeFieldLabel, req.hsCode ?? '-'),
                _buildDetailRow(l10n.commodityDescFieldLabel, req.commodityDescription ?? '-'),
                _buildDetailRow(l10n.foreignSupplierFieldLabel, req.supplierName ?? '-'),
                _buildDetailRow(l10n.countryOfOriginFieldLabel, req.countryOfOrigin ?? '-'),
                _buildDetailRow(l10n.valueInCurrencyFieldLabel, '${req.shipmentValue.toStringAsFixed(2)} ${req.currency ?? ""}'),
                _buildDetailRow(l10n.makerAssessedByLabel, req.assessedBy),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // 5 Compliance Pillars
                _buildSectionHeader(l10n.importRequirementsFormTab),
                const SizedBox(height: 8),
                _buildDetailRow(
                  l10n.pillar1Decree43Tab,
                  req.decree43Applicable
                      ? (req.whiteListVerified
                          ? (req.factoryRegistrationNo ?? l10n.decree43VerifiedBadge)
                          : (req.decree43Action ?? l10n.decree43NotRegisteredBadge))
                      : '-',
                ),
                _buildDetailRow(
                  l10n.pillar2CooTab,
                  req.cooRequired ? '${req.cooType ?? "COO"} - ${req.cooStatus}' : '-',
                ),
                _buildDetailRow(
                  l10n.pillar3InspectionTab,
                  req.inspectionRequired ? '${req.inspectionBody ?? "Inspection"} - ${req.inspectionStatus}' : '-',
                ),
                _buildDetailRow(
                  l10n.pillar4PermitsTab,
                  req.importPermitRequired
                      ? '${DomainEnums.label(l10n, DomainEnumType.regulatoryBody, req.permitIssuingAuthority, fallback: "Authority")} - ${req.permitStatus}'
                      : '-',
                ),
                _buildDetailRow(
                  l10n.pillar5TechCertsTab,
                  req.isPostAcidConfirmed ? l10n.overallStatusConfirmedOption : req.sailingStatus,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Advanced Pillars & Governance
                _buildSectionHeader(l10n.checkerSectionTitle),
                const SizedBox(height: 8),
                _buildDetailRow(
                  l10n.checkerDecisionLabel,
                  req.isOverridden
                      ? l10n.checkerStatusOverriddenBadge
                      : (req.checkerApproved ? l10n.checkerStatusApprovedBadge : l10n.checkerStatusPendingBadge),
                ),
                if (req.isOverridden && req.overrideReason != null)
                  _buildDetailRow(l10n.checkerOverrideReasonLabel, req.overrideReason!),
                if (req.checkerNotes != null && req.checkerNotes!.isNotEmpty)
                  _buildDetailRow(l10n.checkerNotesLabel, req.checkerNotes!),
                if (req.assessmentNotes != null && req.assessmentNotes!.isNotEmpty)
                  _buildDetailRow(l10n.requirementsTsvHeaderNotes, req.assessmentNotes!),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          AppButton(
            label: l10n.governanceActionTooltip,
            icon: Icons.gavel_rounded,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () {
              Navigator.pop(context);
              MakerCheckerDialog.show(
                context,
                requirement: req,
                onDecisionApplied: onRequirementUpdated,
              );
            },
          ),
          AppButton(
            label: l10n.requirementCopySummaryBtn,
            icon: Icons.copy,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () {
              final summary = _buildRequirementSummary(l10n, req);
              CopyHelper.copy(context, summary, customMessage: l10n.requirementCopySummarySuccess);
            },
          ),
          AppButton(
            label: l10n.printRequirementSlipBtn,
            icon: Icons.print,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () {
              Navigator.pop(context);
              MasterDataExportService.printOrSaveImportRequirementSlipPdf(context, req);
            },
          ),
          AppButton(
            label: l10n.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCopyableBadge(BuildContext context, String text, Color color, String tooltip) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, text, customMessage: tooltip),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}
