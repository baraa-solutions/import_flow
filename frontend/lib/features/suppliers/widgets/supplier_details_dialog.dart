import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../core/export/widgets/export_language_dialog.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/supplier_model.dart';

class SupplierDetailsDialog extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback? onEdit;

  const SupplierDetailsDialog({
    super.key,
    required this.supplier,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    SupplierModel supplier, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SupplierDetailsDialog(supplier: supplier, onEdit: onEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = l10n.isArabic;
    final isActive = supplier.isActive;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 780),
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
                      color: AppTheme.orange.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flight_takeoff_rounded, color: AppTheme.orange, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SelectableText(
                                supplier.supplierCode,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: SelectableText(
                                supplier.companyName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: l10n.suppliersCopyFieldTooltip,
                              child: InkWell(
                                onTap: () => CopyHelper.copy(context, supplier.companyName),
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
                            const SizedBox(width: 8),
                            Tooltip(
                              message: l10n.supplierCopySummaryBtn,
                              child: InkWell(
                                onTap: () {
                                  final summary = '''
[${supplier.supplierCode}] ${supplier.companyName}
${l10n.supplierTsvHeaderType}: ${supplier.supplierType} | ${l10n.supplierTsvHeaderRegType}: ${supplier.registrationType}
${l10n.supplierTsvHeaderForeignExporterId}: ${supplier.foreignExporterId} | ${l10n.supplierTsvHeaderCargoxId}: ${supplier.cargoxPlatformId ?? '-'}
${l10n.supplierTsvHeaderCountry}: ${supplier.foreignExporterCountry} (${supplier.foreignExporterCountryCode})
${l10n.supplierTsvHeaderAddress}: ${supplier.address}
${l10n.supplierTsvHeaderPhone}: ${supplier.phone ?? '-'} | ${l10n.supplierTsvHeaderEmail}: ${supplier.email ?? '-'}
${l10n.supplierTsvHeaderBankName}: ${supplier.bankName ?? '-'} | ${l10n.supplierTsvHeaderSwiftCode}: ${supplier.swiftCode ?? '-'}
${l10n.supplierTsvHeaderIban}: ${supplier.iban ?? '-'}
${l10n.supplierTsvHeaderStatus}: ${supplier.isActive ? l10n.statusActive : l10n.statusInactive}
${l10n.supplierTsvHeaderBrands}: ${supplier.brands ?? '-'}
WIPO Madrid: ${supplier.hasWipo ? (supplier.wipoNumber ?? 'Yes') : 'No'} | EUIPO: ${supplier.hasEuipo ? (supplier.euipoNumber ?? 'Yes') : 'No'}
Global Brand: ${supplier.hasGlobalBrand ? (supplier.globalBrandNumber ?? 'Yes') : 'No'} | ISO 9001: ${supplier.hasIso9001 ? (supplier.iso9001Number ?? 'Yes') : 'No'}
'''.trim();
                                  CopyHelper.copy(context, summary, customMessage: l10n.supplierCopySummarySuccess);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.copy_all_rounded, size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                          l10n.supplierProfileSubtitle,
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
                    // Section 1: Nafeza & CargoX & Exporter Identifiers
                    _buildSectionHeader(Icons.hub_outlined, l10n.nafezaCargoXComplianceHeader),
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
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.foreignExporterIdFieldLabel,
                                  value: supplier.foreignExporterId,
                                  icon: Icons.fingerprint_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.cargoxPlatformIdFieldLabel,
                                  value: supplier.cargoxPlatformId ?? l10n.notRegisteredCargoX,
                                  icon: Icons.cloud_done_outlined,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoField(
                                  label: l10n.supplierTypeFieldLabel,
                                  value: '${supplier.supplierType} (${supplier.registrationType})',
                                  icon: Icons.category_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoField(
                                  label: l10n.supplierOriginCountryFieldLabel,
                                  value: '${supplier.foreignExporterCountry} (${supplier.foreignExporterCountryCode.toUpperCase()})',
                                  icon: Icons.public,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          // Compliance Badges
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Text(l10n.complianceCertificatesLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                              _buildComplianceTag(l10n.isoCertifiedTag, supplier.hasIso, Icons.verified_outlined),
                              _buildComplianceTag(l10n.decree43Tag, supplier.registeredDecree43, Icons.policy_outlined),
                              _buildComplianceTag(l10n.whiteListTag, supplier.whiteListRegistered, Icons.shield_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 2: Beneficiary Banking & SWIFT Details
                    _buildSectionHeader(Icons.account_balance_rounded, l10n.bankingSwiftSectionHeader),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.beneficiaryBankFieldLabel,
                                  value: supplier.bankName ?? '-',
                                  icon: Icons.account_balance,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.swiftCodeFieldLabel,
                                  value: supplier.swiftCode ?? '-',
                                  icon: Icons.flash_on_rounded,
                                  highlightColor: AppTheme.cobalt,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.accountNumberFieldLabel,
                                  value: supplier.accountNumber ?? '-',
                                  icon: Icons.pin_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.ibanFieldLabel,
                                  value: supplier.iban ?? '-',
                                  icon: Icons.credit_card_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 3: Contact & Address & Brands
                    _buildSectionHeader(Icons.contact_mail_outlined, l10n.contactAddressBrandsHeader),
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
                          _buildCopyableInfoField(
                            context: context,
                            label: l10n.fullAddressFieldLabel,
                            value: supplier.address,
                            icon: Icons.location_on_outlined,
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.phoneFieldLabel,
                                  value: supplier.phone ?? supplier.mobile ?? '-',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildCopyableInfoField(
                                  context: context,
                                  label: l10n.emailFieldLabel,
                                  value: supplier.email ?? '-',
                                  icon: Icons.email_outlined,
                                ),
                              ),
                            ],
                          ),
                          if (supplier.website != null && supplier.website!.isNotEmpty) ...[
                            const Divider(height: 14),
                            _buildCopyableInfoField(
                              context: context,
                              label: l10n.websiteFieldLabel,
                              value: supplier.website!,
                              icon: Icons.language_outlined,
                            ),
                          ],
                          if (supplier.brands != null && supplier.brands!.isNotEmpty) ...[
                            const Divider(height: 14),
                            _buildCopyableInfoField(
                              context: context,
                              label: l10n.brandsFieldLabel,
                              value: supplier.brands!,
                              icon: Icons.sell_outlined,
                              highlightColor: AppTheme.orange,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section 4: Trademark Certificates & ISO 9001
                    _buildSectionHeader(Icons.verified_user_outlined, isArabic ? 'شهادات العلامة التجارية والجودة' : 'Trademark & Quality Certificates'),
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
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleInfoField(
                                  icon: Icons.verified_outlined,
                                  label: 'WIPO Madrid Monitor',
                                  value: supplier.hasWipo
                                      ? (supplier.wipoNumber != null && supplier.wipoNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${supplier.wipoNumber})' : 'Registered (#${supplier.wipoNumber})')
                                          : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                                      : (isArabic ? 'غير مسجل' : 'Not Registered'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoField(
                                  icon: Icons.verified_outlined,
                                  label: isArabic ? 'مكتب الملكية الفكرية الأوروبي (EUIPO)' : 'EUIPO',
                                  value: supplier.hasEuipo
                                      ? (supplier.euipoNumber != null && supplier.euipoNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${supplier.euipoNumber})' : 'Registered (#${supplier.euipoNumber})')
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
                                child: _buildSimpleInfoField(
                                  icon: Icons.public,
                                  label: 'Global Brand Database',
                                  value: supplier.hasGlobalBrand
                                      ? (supplier.globalBrandNumber != null && supplier.globalBrandNumber!.isNotEmpty
                                          ? (isArabic ? 'مسجل (#${supplier.globalBrandNumber})' : 'Registered (#${supplier.globalBrandNumber})')
                                          : (isArabic ? 'نعم (مسجل)' : 'Yes (Registered)'))
                                      : (isArabic ? 'غير مسجل' : 'Not Registered'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleInfoField(
                                  icon: Icons.workspace_premium_outlined,
                                  label: isArabic ? 'شهادة آيزو 9001' : 'ISO 9001 Certificate',
                                  value: supplier.hasIso9001
                                      ? (supplier.iso9001Number != null && supplier.iso9001Number!.isNotEmpty
                                          ? (isArabic ? 'معتمد (#${supplier.iso9001Number})' : 'Certified (#${supplier.iso9001Number})')
                                          : (isArabic ? 'نعم (معتمد)' : 'Yes (Certified)'))
                                      : (isArabic ? 'غير معتمد' : 'Not Certified'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildSectionHeader(Icons.notes_rounded, l10n.additionalNotesHeader),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          supplier.notes!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action Toolbar (طباعة - حفظ PDF - تنزيل إكسل - واتس - إيميل) ────
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
                  // Left Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 1. Print / Save PDF
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
                          await MasterDataExportService.printOrSaveSupplierPdf(supplier, lang: lang);
                        },
                      ),

                      // 2. Export Excel
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
                          final path = await MasterDataExportService.exportSupplierToExcel(context, supplier, lang: lang);
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                            );
                          }
                        },
                      ),

                      // 3. Export CSV
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
                          final path = await MasterDataExportService.exportSupplierToCsv(context, supplier, lang: lang);
                          if (context.mounted && path != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              AppTheme.snackBar(context, l10n.excelSavedSuccess(path), severity: AppSeverity.success),
                            );
                          }
                        },
                      ),

                      // 3. WhatsApp Share
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

                      // 4. Email Share
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

                  // Right Action Buttons: Edit & Close
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
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceTag(String label, bool isCompliant, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isCompliant ? AppTheme.emerald : Colors.grey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (isCompliant ? AppTheme.emerald : Colors.grey).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isCompliant ? AppTheme.emerald : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCompliant ? AppTheme.emerald : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlightColor ?? Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: highlightColor ?? AppTheme.charcoal,
                      ),
                    ),
                  ),
                  if (value != '-' && value != l10n.notRegisteredCargoX)
                    InkWell(
                      onTap: () => CopyHelper.copy(context, value),
                      child: const Icon(Icons.copy, size: 13, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
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
          final text = MasterDataExportService.generateSupplierWhatsAppText(supplier, isArabic: isArabic);
          return AlertDialog(
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
          final subject = MasterDataExportService.generateSupplierEmailSubject(supplier, isArabic: isArabic);
          final body = MasterDataExportService.generateSupplierEmailBody(supplier, isArabic: isArabic);

          return AlertDialog(
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
                  CopyHelper.copy(context, '${l10n.emailSubjectPrefix(subject)}\n\n$body', customMessage: l10n.emailCopiedSuccess);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
