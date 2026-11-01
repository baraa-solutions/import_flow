import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../services/coo_export_service.dart';
import 'visual_draft_coo/china_ccpit_coo_layout.dart';
import 'visual_draft_coo/coo_sheet_helpers.dart';
import 'visual_draft_coo/eur1_coo_layout.dart';

/// Localized message for a blocked COO export (`acid`, `hs_code`, `origin`).
String cooExportBlockedMessage(AppLocalizations l10n, String field) {
  switch (field) {
    case 'acid':
      return l10n.idocBExportBlockedAcid;
    case 'hs_code':
      return l10n.idocBExportBlockedHsCode;
    default:
      return l10n.idocBExportBlockedOrigin;
  }
}

/// Shows the blocked-export SnackBar and returns true when [field] is non-null.
bool showCooExportBlockedIfAny(BuildContext context, String? field) {
  if (field == null) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    AppTheme.snackBar(context, cooExportBlockedMessage(context.l10n, field), severity: AppSeverity.danger),
  );
  return true;
}

class VisualDraftCOOSheet extends StatefulWidget {
  final Map<String, dynamic> templateData;
  final String certificateType;
  final String acidNumber;
  final String? exemptionNotes;
  final VoidCallback? onRefresh;

  const VisualDraftCOOSheet({
    super.key,
    required this.templateData,
    required this.certificateType,
    required this.acidNumber,
    this.exemptionNotes,
    this.onRefresh,
  });

  static String? missingExportField(Map<String, dynamic> t, String? acid) => CooExportService.missingExportField(t, acid);
  static String sanitizeEnglishOnly(String input) => CooSheetHelpers.sanitizeEnglishOnly(input);
  static String extractCleanMainDescription(String input) => CooSheetHelpers.extractCleanMainDescription(input);
  static String formatCooHsCode(String input, {bool isChina = true}) => CooSheetHelpers.formatCooHsCode(input, isChina: isChina);
  static String getPackageTypePlural(dynamic count, String? packageType) => CooSheetHelpers.getPackageTypePlural(count, packageType);
  static String formatCooQuantityBox({
    required dynamic quantity,
    String? unit,
    required dynamic packagesCount,
    String? packageType,
    required dynamic grossWeightKg,
    bool isChina = true,
  }) =>
      CooSheetHelpers.formatCooQuantityBox(
        quantity: quantity,
        unit: unit,
        packagesCount: packagesCount,
        packageType: packageType,
        grossWeightKg: grossWeightKg,
        isChina: isChina,
      );

  @override
  State<VisualDraftCOOSheet> createState() => _VisualDraftCOOSheetState();
}

class _VisualDraftCOOSheetState extends State<VisualDraftCOOSheet> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.ltr, child: _buildSheet(context));
  }

  Widget _buildSheet(BuildContext context) {
    final t = widget.templateData;
    final isChina = widget.certificateType.toUpperCase().contains('CHINA') || widget.certificateType.toUpperCase().contains('CCPIT');
    final isEur1 = widget.certificateType.toUpperCase().contains('EUR.1') || widget.certificateType.toUpperCase().contains('EUR1');

    final cleanAcidNo = CooSheetHelpers.sanitizeEnglishOnly(widget.acidNumber).replaceAll(RegExp(r'[^0-9]'), '');
    final rawCert = t['certificate_number']?.toString() ?? '';
    final certNo = (rawCert.isNotEmpty && !rawCert.startsWith('26C') && !rawCert.startsWith('No A'))
        ? CooSheetHelpers.sanitizeEnglishOnly(rawCert)
        : (cleanAcidNo.isNotEmpty ? 'DRAFT-$cleanAcidNo' : 'DRAFT');

    final tableRows = (t['table_rows'] as List<dynamic>?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList() ??
        [];

    final exporter = CooSheetHelpers.sanitizeEnglishOnly((t['box_1_exporter'] ?? 'EXPORTER / PRODUCER').toString());
    final consignee = CooSheetHelpers.sanitizeEnglishOnly((t['box_2_consignee'] ?? t['box_3_consignee'] ?? 'IMPORTER / CONSIGNEE').toString());
    final transport = CooSheetHelpers.sanitizeEnglishOnly((t['box_3_means_of_transport'] ?? t['box_6_transport_details'] ?? 'BY SEA').toString());
    final destination = CooSheetHelpers.sanitizeEnglishOnly((t['box_4_country_of_destination'] ?? t['box_5_country_destination'] ?? 'EGYPT').toString());
    final origin = CooSheetHelpers.sanitizeEnglishOnly((t['country_of_origin'] ?? t['box_4_country_origin'] ?? '').toString());
    final originsList = (t['countries_of_origin_list'] as List<dynamic>?)
            ?.map((e) => CooSheetHelpers.sanitizeEnglishOnly(e.toString()))
            .where((e) => e.isNotEmpty)
            .toList() ??
        [origin];
    final hsCodes = isChina
        ? CooSheetHelpers.formatCooHsCode((t['box_8_hs_code'] ?? t['hs_code'] ?? t['hs_codes'] ?? '').toString())
        : (t['box_8_hs_code'] ?? t['hs_code'] ?? t['hs_codes'] ?? '').toString();
    final hsCodesList = (t['hs_codes_list'] as List<dynamic>?)
            ?.map((e) => isChina ? CooSheetHelpers.formatCooHsCode(e.toString()) : e.toString())
            .toList() ??
        [hsCodes];
    final goodsDesc = CooSheetHelpers.sanitizeEnglishOnly((t['box_7_description_and_acid'] ?? t['box_8_description_packages'] ?? t['description'] ?? 'COMMERCIAL CARGO').toString());

    final rawWeight = (t['box_9_quantity_and_weight'] ?? t['box_9_gross_mass'] ?? '').toString().trim();
    final weight = rawWeight.isNotEmpty
        ? CooSheetHelpers.sanitizeEnglishOnly(rawWeight)
        : CooSheetHelpers.formatCooQuantityBox(
            quantity: t['quantity'] ?? 1152,
            unit: t['unit']?.toString() ?? 'PCS',
            packagesCount: t['packages_count'] ?? 144,
            packageType: t['package_type']?.toString(),
            grossWeightKg: t['gross_weight_kg'] ?? 10510.0,
            isChina: isChina,
          );

    final invoiceData = CooSheetHelpers.sanitizeEnglishOnly((t['box_10_invoice_number_and_date'] ?? t['box_10_invoices_and_acid'] ?? 'INVOICE INFO').toString());
    final remarks = CooSheetHelpers.sanitizeEnglishOnly((t['box_7_remarks'] ?? (isEur1 ? 'REVISED RULES' : 'N/A')).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(isEur1 ? Icons.flag_circle : Icons.verified, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.l10n.cooVisualPreviewTitle(widget.certificateType),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                const SizedBox(width: 16),
                if (widget.onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.cobalt),
                    tooltip: context.l10n.cooVisualRefreshTooltip,
                    onPressed: widget.onRefresh,
                  ),
                AppButton(
                  label: context.l10n.cooVisualCopyButton,
                  onPressed: () {
                    if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                    final text = CooExportService.exportCOOCsv(
                      templateData: t,
                      certificateType: widget.certificateType,
                      acidNumber: widget.acidNumber,
                    );
                    CopyHelper.copy(context, text, customMessage: context.l10n.cooVisualCopiedSnackbar);
                  },
                  variant: AppButtonVariant.secondary,
                  icon: Icons.copy,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: context.l10n.cooVisualExcelButton,
                  onPressed: () async {
                    if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                    final path = await CooExportService.saveCOOCsvToFile(
                      templateData: t,
                      certificateType: widget.certificateType,
                      acidNumber: widget.acidNumber,
                    );
                    if (path != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(context, context.l10n.cooExcelSavedSuccess(path), severity: AppSeverity.success),
                      );
                    } else {
                      final csv = CooExportService.exportCOOCsv(
                        templateData: t,
                        certificateType: widget.certificateType,
                        acidNumber: widget.acidNumber,
                      );
                      if (context.mounted) {
                        CopyHelper.copy(context, csv, customMessage: context.l10n.cooVisualExcelReadySnackbar);
                      }
                    }
                  },
                  variant: AppButtonVariant.secondary,
                  icon: Icons.table_chart_outlined,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: context.l10n.cooVisualPrintPdfButton,
                  onPressed: _isExporting
                      ? null
                      : () async {
                          if (showCooExportBlockedIfAny(context, CooExportService.missingExportField(t, widget.acidNumber))) return;
                          setState(() => _isExporting = true);
                          try {
                            await CooExportService.printOrSavePdf(
                              templateData: t,
                              certificateType: widget.certificateType,
                              acidNumber: widget.acidNumber,
                              exemptionNotes: widget.exemptionNotes,
                            );
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        },
                  icon: Icons.picture_as_pdf,
                  isLoading: _isExporting,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.orange, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: AppTheme.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: CopyableText(
                  context.l10n.cooCustomsClearanceNote,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningForeground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border, width: 1.2),
          ),
          child: isChina
              ? ChinaCcpitCooLayout(
                  certNo: certNo,
                  exporter: exporter,
                  consignee: consignee,
                  transport: transport,
                  destination: destination,
                  goodsDesc: goodsDesc,
                  hsCodesList: hsCodesList,
                  weight: weight,
                  tableRows: tableRows,
                  acidNumber: widget.acidNumber,
                )
              : Eur1CooLayout(
                  certNo: certNo,
                  exporter: exporter,
                  consignee: consignee,
                  transport: transport,
                  destination: destination,
                  goodsDesc: goodsDesc,
                  hsCodesList: hsCodesList,
                  weight: weight,
                  invoiceData: invoiceData,
                  originsList: originsList,
                  remarks: remarks,
                  isEur1: isEur1,
                  tableRows: tableRows,
                  acidNumber: widget.acidNumber,
                ),
        ),
      ],
    );
  }
}
