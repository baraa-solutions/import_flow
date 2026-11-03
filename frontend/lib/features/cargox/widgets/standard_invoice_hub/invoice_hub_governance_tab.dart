import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Approval & Governance tab:
/// Allows switching invoice verification status (Draft, Under Review, Approved, Rejected),
/// requires mandatory justification for discrepancies override when approving,
/// and saves the session.
class InvoiceHubGovernanceTab extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController overrideReasonController;
  final TextEditingController notesController;
  final bool hasIssues;
  final bool isSaving;
  final void Function({bool isDraft}) onSaveSession;

  const InvoiceHubGovernanceTab({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.overrideReasonController,
    required this.notesController,
    required this.hasIssues,
    required this.isSaving,
    required this.onSaveSession,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.standardInvoiceGovernanceTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatusRadio(
                value: 'DRAFT',
                label: l10n.standardInvoiceStatusDraft,
                color: Colors.grey,
              ),
              _buildStatusRadio(
                value: 'UNDER_REVIEW',
                label: l10n.standardInvoiceStatusUnderReview,
                color: AppTheme.orange,
              ),
              _buildStatusRadio(
                value: 'APPROVED',
                label: l10n.standardInvoiceStatusApproved,
                color: AppTheme.emerald,
              ),
              _buildStatusRadio(
                value: 'REJECTED_NEEDS_MODIFICATION',
                label: l10n.standardInvoiceStatusRejected,
                color: AppTheme.crimson,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (selectedStatus == 'APPROVED' && hasIssues) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.crimson),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: AppTheme.crimson),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.standardInvoiceOverrideWarningBanner,
                      style: const TextStyle(
                        color: AppTheme.crimson,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: overrideReasonController,
              decoration: InputDecoration(
                labelText: l10n.standardInvoiceOverrideReasonLabel,
                hintText: l10n.standardInvoiceOverrideReasonHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.gavel, color: AppTheme.crimson),
              ),
              maxLines: 3,
              validator: (v) {
                if (selectedStatus == 'APPROVED' && hasIssues && (v == null || v.trim().isEmpty)) {
                  return l10n.standardInvoiceOverrideRequiredError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: l10n.standardInvoiceInternalNotesLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note_alt),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: isAr ? 'حفظ المسودة' : 'Save Draft',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.saveDraft,
                  isLoading: false,
                  onPressed: isSaving ? null : () => onSaveSession(isDraft: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: l10n.standardInvoiceSaveSessionBtn,
                  icon: Icons.check_circle_outline,
                  variant: AppButtonVariant.success,
                  isLoading: isSaving,
                  onPressed: isSaving ? null : () => onSaveSession(isDraft: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRadio({
    required String value,
    required String label,
    required Color color,
  }) {
    final isSelected = selectedStatus == value;
    return InkWell(
      onTap: () => onStatusChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
