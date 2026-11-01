import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class NafezaParsedMtsResultCard extends StatelessWidget {
  final Map<String, dynamic> parsedData;
  final bool isSaving;
  final VoidCallback onGoToVerification;
  final VoidCallback onSaveCertified;
  final VoidCallback onSaveDraft;
  final VoidCallback onEdit;
  final VoidCallback onCodeSupplier;

  const NafezaParsedMtsResultCard({
    super.key,
    required this.parsedData,
    required this.isSaving,
    required this.onGoToVerification,
    required this.onSaveCertified,
    required this.onSaveDraft,
    required this.onEdit,
    required this.onCodeSupplier,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;
    final hasAcid = parsedData['acid_number']?.toString().isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAcid
              ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobaltBorder)
              : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasAcid ? Icons.check_circle : Icons.warning_amber_rounded,
                color: hasAcid
                    ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                    : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasAcid ? l.parsedMtsSuccessTitle : l.parsedMtsNoAcidTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasAcid
                        ? (isDark ? AppTheme.wcagEmerald : AppTheme.cobalt)
                        : (isDark ? AppTheme.wcagOrange : AppTheme.orange),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: l.goToVerificationButton,
                onPressed: onGoToVerification,
                icon: Icons.compare_arrows,
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildExtractedField(context, l.acidNumberCol, hasAcid ? parsedData['acid_number']!.toString() : '-'),
              _buildExtractedField(context, l.issueDateCol, parsedData['generated_date']?.toString() ?? '-'),
              _buildExtractedField(context, l.expiryDateCol, parsedData['expiry_date']?.toString() ?? '-'),
              _buildExtractedField(context, l.importerCompanyCol, parsedData['importer_name']?.toString() ?? '-'),
              _buildExtractedField(context, l.importerTaxIdLabel, parsedData['importer_tax_id']?.toString() ?? '-'),
              _buildExtractedField(context, l.foreignExporterCol, parsedData['exporter_name']?.toString() ?? '-'),
              _buildExtractedField(context, l.foreignExporterIdLabel, parsedData['exporter_reg_id']?.toString() ?? '-'),
              _buildExtractedField(context, l.regTypeLabel, parsedData['exporter_reg_type']?.toString() ?? 'Company Registration Number'),
              _buildExtractedField(context, l.countryOfOriginExportLabel, parsedData['exporter_country']?.toString() ?? '-'),
              _buildExtractedField(context, l.cargoxPlatformIdLabel, parsedData['cargox_id']?.toString() ?? '-'),
              _buildExtractedField(context, l.proformaInvoiceNoLabel, parsedData['proforma_invoice_no']?.toString() ?? '-'),
              _buildExtractedField(context, l.portOfLoadingLabel, parsedData['pol_name']?.toString() ?? '-'),
              _buildExtractedField(context, l.portOfDischargeLabel, parsedData['pod_name']?.toString() ?? '-'),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppButton(
                label: l.saveAndCertifyAcidButton,
                onPressed: isSaving ? null : onSaveCertified,
                variant: AppButtonVariant.success,
                icon: Icons.save_as,
              ),
              AppButton(
                label: l.saveTempDraftButton,
                onPressed: isSaving ? null : onSaveDraft,
                icon: Icons.save_outlined,
              ),
              AppButton(
                label: l.editExtractedDataButton,
                onPressed: onEdit,
                variant: AppButtonVariant.secondary,
                icon: Icons.edit,
              ),
              AppButton(
                label: l.codeSupplierButton,
                onPressed: onCodeSupplier,
                icon: Icons.business_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedField(BuildContext context, String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => CopyHelper.copy(context, val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            CopyableText(
              val,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
