import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Action cards and buttons for Standard Invoice Hub:
/// - Multi-mode template download / Extraction Engine
/// - Upload and parse Excel invoice
/// - Save draft, approve & commit session, resync actions
class InvoiceHubActionsBar extends StatelessWidget {
  final bool isDownloading;
  final bool isParsing;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onPickAndParseExcel;

  const InvoiceHubActionsBar({
    super.key,
    required this.isDownloading,
    required this.isParsing,
    required this.onDownloadTemplate,
    required this.onPickAndParseExcel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _buildToolActionCard(
            title: l10n.standardInvoiceTool1Title,
            subtitle: l10n.standardInvoiceTool1Subtitle,
            icon: Icons.download_for_offline,
            color: AppTheme.emerald,
            buttonLabel: l10n.standardInvoiceTool1Btn,
            isLoading: isDownloading,
            variant: AppButtonVariant.success,
            onTap: onDownloadTemplate,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildToolActionCard(
            title: l10n.standardInvoiceTool2Title,
            subtitle: l10n.standardInvoiceTool2Subtitle,
            icon: Icons.upload_file,
            color: AppTheme.cobalt,
            buttonLabel: l10n.standardInvoiceTool2Btn,
            isLoading: isParsing,
            variant: AppButtonVariant.primary,
            onTap: onPickAndParseExcel,
          ),
        ),
      ],
    );
  }

  Widget _buildToolActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonLabel,
    required bool isLoading,
    required AppButtonVariant variant,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: buttonLabel,
              icon: icon,
              variant: variant,
              isLoading: isLoading,
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone action buttons for saving, approving, and resyncing invoice sessions.
class InvoiceHubSessionActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onApproveAndSave;
  final VoidCallback? onResyncComparison;

  const InvoiceHubSessionActionButtons({
    super.key,
    required this.isSaving,
    required this.onSaveDraft,
    required this.onApproveAndSave,
    this.onResyncComparison,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Row(
      children: [
        if (onResyncComparison != null) ...[
          Expanded(
            child: AppButton(
              label: isAr ? 'إعادة المطابقة' : 'Re-sync & Match',
              icon: Icons.sync,
              variant: AppButtonVariant.secondary,
              onPressed: isSaving ? null : onResyncComparison,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: AppButton(
            label: isAr ? 'حفظ المسودة' : 'Save Draft',
            icon: Icons.save_outlined,
            variant: AppButtonVariant.saveDraft,
            isLoading: false,
            onPressed: isSaving ? null : onSaveDraft,
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
            onPressed: isSaving ? null : onApproveAndSave,
          ),
        ),
      ],
    );
  }
}
