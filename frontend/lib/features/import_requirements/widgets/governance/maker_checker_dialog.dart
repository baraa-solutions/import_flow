import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_requirement_model.dart';
import '../../providers/import_requirements_provider.dart';

enum GovernanceDecision { approve, override, reject }

/// 🛡️ Maker-Checker Governance Dialog — ImportFlow ERP
///
/// Implements dual-control compliance governance (Four-Eyes Principle)
/// for import requirement assessments, allowing a designated checker to
/// approve, reject, or execute an executive override with statutory justification.
class MakerCheckerDialog extends ConsumerStatefulWidget {
  final ImportRequirementModel requirement;
  final ValueChanged<ImportRequirementModel>? onDecisionApplied;

  const MakerCheckerDialog({
    super.key,
    required this.requirement,
    this.onDecisionApplied,
  });

  static Future<void> show(
    BuildContext context, {
    required ImportRequirementModel requirement,
    ValueChanged<ImportRequirementModel>? onDecisionApplied,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MakerCheckerDialog(
        requirement: requirement,
        onDecisionApplied: onDecisionApplied,
      ),
    );
  }

  @override
  ConsumerState<MakerCheckerDialog> createState() => _MakerCheckerDialogState();
}

class _MakerCheckerDialogState extends ConsumerState<MakerCheckerDialog> {
  final _formKey = GlobalKey<FormState>();
  late GovernanceDecision _decision;
  late TextEditingController _reviewerCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _overrideReasonCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.requirement.isOverridden) {
      _decision = GovernanceDecision.override;
    } else if (widget.requirement.checkerApproved) {
      _decision = GovernanceDecision.approve;
    } else {
      _decision = GovernanceDecision.approve;
    }

    _reviewerCtrl = TextEditingController(text: 'مدير الرقابة والامتثال');
    _notesCtrl = TextEditingController(text: widget.requirement.checkerNotes ?? '');
    _overrideReasonCtrl = TextEditingController(text: widget.requirement.overrideReason ?? '');
  }

  @override
  void dispose() {
    _reviewerCtrl.dispose();
    _notesCtrl.dispose();
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitDecision() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.requirement.assessmentId == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    final l10n = context.l10n;

    try {
      final isApproved = _decision == GovernanceDecision.approve || _decision == GovernanceDecision.override;
      final isOverridden = _decision == GovernanceDecision.override;
      final updateData = <String, dynamic>{
        'checker_approved': isApproved,
        'checker_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'is_overridden': isOverridden,
        'override_reason': isOverridden ? _overrideReasonCtrl.text.trim() : null,
      };

      if (isApproved && widget.requirement.overallStatus == 'Draft') {
        updateData['overall_status'] = 'Confirmed';
      } else if (_decision == GovernanceDecision.reject) {
        updateData['overall_status'] = 'In Progress';
      }

      await ref.read(importRequirementsProvider.notifier).updateRequirement(
            widget.requirement.assessmentId!,
            updateData,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.checkerSuccessSnack, severity: AppSeverity.success),
        );

        final updatedReq = widget.requirement.copyWith(
          checkerApproved: isApproved,
          checkerNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isOverridden: isOverridden,
          overrideReason: isOverridden ? _overrideReasonCtrl.text.trim() : null,
          overallStatus: updateData['overall_status'] as String? ?? widget.requirement.overallStatus,
        );
        widget.onDecisionApplied?.call(updatedReq);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, '${l10n.checkerErrorSnack}: $e', severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _getRiskColor(String risk) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = widget.requirement;

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: AppTheme.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.makerCheckerDialogTitle,
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.makerCheckerDialogSubtitle,
                            style: const TextStyle(
                              color: AppTheme.cloudWhite,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.cloudWhite, size: 20),
                      tooltip: l10n.checkerCancelBtn,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Maker Assessment Snapshot Card
                        _buildMakerSnapshotCard(context, req, l10n),
                        const SizedBox(height: 18),

                        // Checker Governance Section
                        Text(
                          l10n.checkerSectionTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Reviewer Name Field
                        CustomTextField(
                          controller: _reviewerCtrl,
                          label: l10n.checkerReviewerNameLabel,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),

                        // Decision Selector (Radio Cards)
                        _buildDecisionSelector(context, l10n),
                        const SizedBox(height: 12),

                        // Mandatory Override Justification Field
                        if (_decision == GovernanceDecision.override) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.checkerOverrideReasonLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _overrideReasonCtrl,
                                  maxLines: 3,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return l10n.checkerOverrideReasonLabel;
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: l10n.checkerOverrideReasonHint,
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: AppTheme.white,
                                    contentPadding: const EdgeInsets.all(10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Checker Notes Field
                        CustomTextField(
                          controller: _notesCtrl,
                          label: l10n.checkerNotesLabel,
                          hint: l10n.checkerNotesHint,
                          maxLines: 2,
                          icon: Icons.notes_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions Bottom Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: AppTheme.cloudWhite)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: l10n.checkerCancelBtn,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.medium,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: l10n.checkerApproveBtn,
                      icon: Icons.check_circle_outline,
                      variant: _decision == GovernanceDecision.reject
                          ? AppButtonVariant.danger
                          : _decision == GovernanceDecision.override
                              ? AppButtonVariant.warning
                              : AppButtonVariant.primary,
                      size: AppButtonSize.medium,
                      isLoading: _isSaving,
                      onPressed: _submitDecision,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMakerSnapshotCard(BuildContext context, ImportRequirementModel req, AppLocalizations l10n) {
    final riskColor = _getRiskColor(req.riskLevel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.makerSectionTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => CopyHelper.copy(context, req.assessmentCode, customMessage: l10n.copyAssessmentCodeTooltip),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 11, color: AppTheme.cobalt),
                      const SizedBox(width: 4),
                      Text(
                        req.assessmentCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details Grid
          Row(
            children: [
              Expanded(
                child: _buildMetaItem(l10n.makerAssessedByLabel, req.assessedBy),
              ),
              Expanded(
                child: _buildMetaItem(
                  l10n.makerRiskLevelLabel,
                  req.riskLevel,
                  color: riskColor,
                  isBadge: true,
                ),
              ),
              Expanded(
                child: _buildMetaItem(
                  l10n.makerOverallStatusLabel,
                  req.overallStatus,
                  color: AppTheme.cobalt,
                  isBadge: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Active Regulatory Safeguards Badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (req.decree43Applicable)
                _buildSafeguardBadge(
                  l10n.pillar1Decree43Tab,
                  req.whiteListVerified ? AppTheme.emerald : AppTheme.orange,
                  req.whiteListVerified ? Icons.check_circle_outline : Icons.pending_outlined,
                ),
              if (req.cooRequired)
                _buildSafeguardBadge(
                  l10n.pillar2CooTab,
                  req.cooStatus == 'Obtained' ? AppTheme.emerald : AppTheme.orange,
                  Icons.public,
                ),
              if (req.inspectionRequired)
                _buildSafeguardBadge(
                  l10n.pillar3InspectionTab,
                  req.inspectionStatus == 'Completed' ? AppTheme.emerald : AppTheme.orange,
                  Icons.fact_check_outlined,
                ),
              if (req.importPermitRequired)
                _buildSafeguardBadge(
                  l10n.pillar4PermitsTab,
                  req.permitStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
                  Icons.verified_outlined,
                ),
              if (req.isHazmat)
                _buildSafeguardBadge(
                  l10n.hazardousMaterialsHeader,
                  AppTheme.crimson,
                  Icons.warning_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {Color? color, bool isBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? AppTheme.charcoal).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color ?? AppTheme.charcoal,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
      ],
    );
  }

  Widget _buildSafeguardBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionSelector(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.checkerDecisionLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildDecisionCard(
                decision: GovernanceDecision.approve,
                title: l10n.checkerDecisionApprove,
                icon: Icons.check_circle_outline,
                activeColor: AppTheme.emerald,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecisionCard(
                decision: GovernanceDecision.override,
                title: l10n.checkerDecisionOverride,
                icon: Icons.shield_outlined,
                activeColor: AppTheme.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDecisionCard(
                decision: GovernanceDecision.reject,
                title: l10n.checkerDecisionReject,
                icon: Icons.cancel_outlined,
                activeColor: AppTheme.crimson,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDecisionCard({
    required GovernanceDecision decision,
    required String title,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _decision == decision;

    return InkWell(
      onTap: () => setState(() => _decision = decision),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cloudWhite,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppTheme.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
