import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/export/widgets/export_language_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/import_company_model.dart';

class ImportCompanyDetailsDialog extends StatelessWidget {
  final ImportCompanyModel company;
  final VoidCallback? onEdit;

  const ImportCompanyDetailsDialog({
    super.key,
    required this.company,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    ImportCompanyModel company, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ImportCompanyDetailsDialog(company: company, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = l10n.isArabic;
    final isActive = company.isActive;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: SelectableText(
                                  company.importerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: l10n.importCompaniesCopyFieldTooltip,
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(context, company.importerName),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.copy_rounded, size: 15, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isActive ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isActive ? AppTheme.emerald : AppTheme.crimson,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isActive ? l10n.statusActive : l10n.statusInactive,
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          l10n.importerProfileSubtitle,
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    tooltip: l10n.close,
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Official Identifiers & Registrations
                    _buildSectionHeader(Icons.verified_user_rounded, l10n.officialRegistrationsHeader),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            context: context,
                            icon: Icons.badge_outlined,
                            label: l10n.importerCardIdRowLabel,
                            value: company.importerId,
                            expiryDate: company.importerIdExpiry,
                            daysRemaining: company.daysUntilImporterIdExpiry,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            context: context,
                            icon: Icons.receipt_long_outlined,
                            label: l10n.vatTaxIdRowLabel,
                            value: company.vatId,
                            expiryDate: company.vatIdExpiry,
                            daysRemaining: company.daysUntilVatExpiry,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            context: context,
                            icon: Icons.account_balance_outlined,
                            label: l10n.commercialRegRowLabel,
                            value: company.registrationNumber,
                            expiryDate: company.registrationExpiry,
                            daysRemaining: company.daysUntilRegExpiry,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Address & Contact Details
                    _buildSectionHeader(Icons.location_on_outlined, l10n.locationAndContactHeader),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildSimpleInfoRow(context, Icons.public, l10n.countryRowLabel, company.country.isNotEmpty ? company.country : l10n.egyptCountryFallback),
                          const Divider(height: 14),
                          _buildSimpleInfoRow(context, Icons.home_outlined, l10n.addressRowLabel, company.address),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.phone_outlined, l10n.phoneRowLabel, company.phone ?? '-'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.smartphone, l10n.importCompaniesMobileLabel, company.mobileNumber ?? '-'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.print, l10n.importCompaniesFaxLabel, company.faxNumber ?? '-'),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.email_outlined, isArabic ? 'البريد الأساسي' : 'Primary Email', company.primaryEmail ?? company.email ?? '-'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.mark_email_read_outlined, isArabic ? 'البريد الثانوي' : 'Secondary Email', company.secondaryEmail ?? '-'),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoRow(context, Icons.language, l10n.importCompaniesWebsiteLabel, company.website ?? '-'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(
                                  context,
                                  Icons.vpn_key_rounded,
                                  l10n.importCompaniesNafezaTokenLabel,
                                  company.maskedNafezaToken ?? (company.hasNafezaToken ? '****' : '-'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Section 3: Trademark & Quality Certificates ───────────────────
                    _buildSectionHeader(Icons.verified_rounded, l10n.importCompaniesCertificatesSection),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoRow(
                                  context,
                                  Icons.verified_outlined,
                                  'WIPO Madrid Monitor',
                                  company.hasWipo
                                      ? (company.wipoNumber != null && company.wipoNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${company.wipoNumber})' : 'Registered (#${company.wipoNumber})')
                                          : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                                      : (isArabic ? 'غير مسجل' : 'Not Registered'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(
                                  context,
                                  Icons.verified_outlined,
                                  isArabic ? 'مكتب الملكية الفكرية الأوروبي (EUIPO)' : 'EUIPO',
                                  company.hasEuipo
                                      ? (company.euipoNumber != null && company.euipoNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${company.euipoNumber})' : 'Registered (#${company.euipoNumber})')
                                          : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                                      : (isArabic ? 'غير مسجل' : 'Not Registered'),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoRow(
                                  context,
                                  Icons.public,
                                  'Global Brand Database',
                                  company.hasGlobalBrand
                                      ? (company.globalBrandNumber != null && company.globalBrandNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${company.globalBrandNumber})' : 'Registered (#${company.globalBrandNumber})')
                                          : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                                      : (isArabic ? 'غير مسجل' : 'Not Registered'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoRow(
                                  context,
                                  Icons.workspace_premium_outlined,
                                  isArabic ? 'شهادة آيزو 9001' : 'ISO 9001 Certificate',
                                  company.hasIso9001
                                      ? (company.iso9001Number != null && company.iso9001Number!.isNotEmpty
                                          ? (isArabic ? 'معتمد (#${company.iso9001Number})' : 'Certified (#${company.iso9001Number})')
                                          : (isArabic ? 'نعم (معتمد)' : 'Yes (Certified)'))
                                      : (isArabic ? 'غير معتمد' : 'Not Certified'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (company.notes != null && company.notes!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionHeader(Icons.notes_rounded, l10n.administrativeNotesHeader),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SelectableText(
                                company.notes!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: l10n.importCompaniesCopyFieldTooltip,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(context, company.notes!),
                                child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action Toolbar (طباعة - حفظ PDF - تنزيل إكسل - واتس - إيميل - نسخ كامل) ────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Left Buttons: Print, PDF, Excel, Copy All, WhatsApp
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 1. Copy All Info
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: Text(l10n.importCompanyCopySummaryBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final fullText = MasterDataExportService.generateImporterWhatsAppText(
                            company,
                            isArabic: context.l10n.isArabic,
                          );
                          CopyHelper.copy(context, fullText, customMessage: l10n.importCompanyCopySummarySuccess);
                        },
                      ),

                      // 2. Print / Save PDF
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text(l10n.printSavePdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final lang = await ExportLanguageDialog.show(context);
                          if (lang == null) return;
                          await MasterDataExportService.printOrSaveImporterPdf(company, lang: lang);
                        },
                      ),

                      // 3. Export Excel
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E7E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.table_view_rounded, size: 16),
                        label: Text(l10n.downloadExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final lang = await ExportLanguageDialog.show(context);
                          if (lang == null) return;
                          if (!context.mounted) return;
                          final path = await MasterDataExportService.exportImporterToExcel(context, company, lang: lang);
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                            );
                          }
                        },
                      ),

                      // 4. Export CSV
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.description_rounded, size: 16),
                        label: Text(l10n.tableExportCsv, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final lang = await ExportLanguageDialog.show(context);
                          if (lang == null) return;
                          if (!context.mounted) return;
                          final path = await MasterDataExportService.exportImporterToCsv(context, company, lang: lang);
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                            );
                          }
                        },
                      ),

                      // 5. WhatsApp Share
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: Text(l10n.whatsappShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showWhatsAppPreviewModal(context),
                      ),

                      // 5. Email Share
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 16),
                        label: Text(l10n.emailShareBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showEmailPreviewModal(context),
                      ),
                    ],
                  ),

                  // Right Buttons: Edit & Close
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoal,
                            side: const BorderSide(color: AppTheme.charcoal),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(l10n.edit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context);
                            onEdit!();
                          },
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ],
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        SelectableText(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required DateTime expiryDate,
    required int daysRemaining,
  }) {
    final l10n = context.l10n;
    final isExpired = daysRemaining <= 0;
    final isWarning = daysRemaining > 0 && daysRemaining <= 30;

    Color badgeBg = AppTheme.emerald.withValues(alpha: 0.12);
    Color badgeColor = AppTheme.emerald;
    String statusText = l10n.expiryValidDaysRemaining(daysRemaining);

    if (isExpired) {
      badgeBg = AppTheme.crimson.withValues(alpha: 0.12);
      badgeColor = AppTheme.crimson;
      statusText = l10n.expiryExpired;
    } else if (isWarning) {
      badgeBg = AppTheme.orange.withValues(alpha: 0.15);
      badgeColor = AppTheme.orange;
      statusText = l10n.expiryEndingSoon(daysRemaining);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  SelectableText(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
                    child: InkWell(
                      onTap: () => CopyHelper.copy(context, value),
                      child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(l10n.expiryDateLabel(expiryDate.toIso8601String().split('T')[0]), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                statusText,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleInfoRow(BuildContext context, IconData icon, String label, String value) {
    final l10n = context.l10n;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                    ),
                  ),
                  if (value != '-')
                    Tooltip(
                      message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
                      child: InkWell(
                        onTap: () => CopyHelper.copy(context, value),
                        child: const Icon(Icons.copy, size: 13, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showWhatsAppPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final text = MasterDataExportService.generateImporterWhatsAppText(company, isArabic: isArabic);
          return SelectionArea(
            child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.whatsappPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                    ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {isArabic},
                  onSelectionChanged: (newSelection) {
                    setModalState(() => isArabic = newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: SelectableText(
                      text,
                      style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                label: Text(l10n.copyWhatsappTextBtn, style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(ctx);
                  CopyHelper.copy(context, text, customMessage: l10n.whatsappCopiedSuccess);
                },
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  void _showEmailPreviewModal(BuildContext context) {
    final l10n = context.l10n;
    bool isArabic = l10n.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final subject = MasterDataExportService.generateImporterEmailSubject(company, isArabic: isArabic);
          final body = MasterDataExportService.generateImporterEmailBody(company, isArabic: isArabic);

          return SelectionArea(
            child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.emailPreviewTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('عربي', style: TextStyle(fontSize: 11))),
                    ButtonSegment<bool>(value: false, label: Text('EN', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {isArabic},
                  onSelectionChanged: (newSelection) {
                    setModalState(() => isArabic = newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.emailSubjectPrefix(subject), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      body,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                label: Text(l10n.copyEmailTextBtn, style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(ctx);
                  CopyHelper.copy(context, '$subject\n\n$body', customMessage: l10n.emailCopiedSuccess);
                },
              ),
            ],
          ),
        );
        },
      ),
    );
  }
}
