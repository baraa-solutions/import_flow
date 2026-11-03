import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';

/// ACID Items Compliance Checklist & Discrepancy Matrix Component
///
/// Features:
/// - Verifies requested customs declaration figures against MTS-generated values.
/// - Validates Importer, Exporter, Country, Invoice, Ports, and CargoX ID compliance.
/// - Allows justified operational override for verified discrepancies.
/// - Wrapped in [SelectionArea] with [CopyHelper.copy] for Bidi-safe copying.
class AcidItemsComplianceChecklist extends ConsumerStatefulWidget {
  final int? selectedImportFileId;
  final Map<String, dynamic>? parsedMtsData;
  final AcidComparisonResult? comparisonResult;
  final ValueChanged<int?>? onImportFileChanged;
  final ValueChanged<AcidComparisonResult?>? onComparisonDone;
  final VoidCallback? onAcidCertified;

  const AcidItemsComplianceChecklist({
    super.key,
    this.selectedImportFileId,
    this.parsedMtsData,
    this.comparisonResult,
    this.onImportFileChanged,
    this.onComparisonDone,
    this.onAcidCertified,
  });

  @override
  ConsumerState<AcidItemsComplianceChecklist> createState() => _AcidItemsComplianceChecklistState();
}

class _AcidItemsComplianceChecklistState extends ConsumerState<AcidItemsComplianceChecklist> {
  int? _selectedImportFileId;
  AcidComparisonResult? _comparisonResult;
  bool _isComparing = false;
  bool _isSaving = false;
  final TextEditingController _overrideReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.selectedImportFileId;
    _comparisonResult = widget.comparisonResult;
  }

  @override
  void didUpdateWidget(AcidItemsComplianceChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImportFileId != oldWidget.selectedImportFileId) {
      setState(() => _selectedImportFileId = widget.selectedImportFileId);
    }
    if (widget.comparisonResult != oldWidget.comparisonResult) {
      setState(() => _comparisonResult = widget.comparisonResult);
    }
  }

  @override
  void dispose() {
    _overrideReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _runComparison() async {
    final l = context.l10n;
    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.selectImportFileToVerify, severity: AppSeverity.danger),
      );
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final comp = companies.where((c) => c.companyId == file?.companyId).firstOrNull;
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final supp = suppliers.where((s) => s.supplierId == file?.supplierId).firstOrNull;
    final pos = ref.read(purchaseOrdersProvider).purchaseOrders;
    final po = pos.where((p) => p.importFileId == _selectedImportFileId).firstOrNull;

    setState(() => _isComparing = true);
    try {
      final requestedData = {
        'import_file_id': _selectedImportFileId,
        'importer_name': comp?.importerName ?? file?.companyName ?? '',
        'importer_tax_id': comp?.vatId ?? '',
        'exporter_name': supp?.companyName ?? file?.supplierName ?? '',
        'exporter_reg_type': supp?.registrationType ?? 'Company Registration Number',
        'exporter_reg_id': supp?.foreignExporterId ?? '',
        'exporter_country': supp?.foreignExporterCountry ?? '',
        'exporter_country_code': supp?.foreignExporterCountryCode ?? '',
        'proforma_invoice_no': file?.piNumber ?? (file?.poNumber ?? (po != null ? po.poNumber : '')),
        'pol_name': 'CHANGSHU',
        'pod_name': 'Alexandria',
        'cargox_id': supp?.cargoxPlatformId ?? '',
      };
      final generatedData = widget.parsedMtsData ?? {};

      final res = await ref.read(acidSessionsProvider.notifier).compareAcid(requestedData, generatedData);
      setState(() => _comparisonResult = res);
      widget.onComparisonDone?.call(res);
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorCustomsComparison, error: e);
      }
    } finally {
      if (mounted) setState(() => _isComparing = false);
    }
  }

  void _copyDiscrepancyReport() {
    if (_comparisonResult == null) return;

    final l = context.l10n;
    final isAr = l.isArabic;
    final buffer = StringBuffer();
    buffer.writeln('📋 ${l.idocBAcidReportTitle}');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('${l.idocBAcidReportOverallStatus}: ${_comparisonResult!.allMatched ? '${l.idocBAcidReportFullyMatched} ✅' : '${l.idocBAcidReportDiscrepancies} ⚠️'}');
    buffer.writeln('${l.idocBAcidReportMatchPercentage}: ${_comparisonResult!.matchPercentage.toStringAsFixed(1)}% (${_comparisonResult!.matchedCount}/${_comparisonResult!.totalComparedFields})');
    buffer.writeln('--------------------------------------------------');

    for (final item in _comparisonResult!.items) {
      final label = isAr ? item.labelAr : item.labelEn;
      final status = item.isMatched ? '✅' : '❌';
      buffer.writeln('$status $label:');
      buffer.writeln('   - ${l.idocBAcidReportRequested}: ${item.requestedValue}');
      buffer.writeln('   - ${l.idocBAcidReportGenerated}: ${item.generatedValue}');
    }

    if (!_comparisonResult!.allMatched && _overrideReasonCtrl.text.trim().isNotEmpty) {
      buffer.writeln('--------------------------------------------------');
      buffer.writeln('${l.idocBAcidReportOverride}: ${_overrideReasonCtrl.text.trim()}');
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l.discrepancyReportCopiedSuccess);
  }

  Future<void> _saveVerifiedAcid() async {
    final l = context.l10n;
    if (_selectedImportFileId == null) return;

    final acidToSave = (widget.parsedMtsData?['acid_number'] ?? '').toString().trim();
    if (acidToSave.isEmpty || acidToSave == 'ACID-EG-2026-') {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.idocBAcidRequired, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final genDateVal = widget.parsedMtsData?['generated_date']?.toString().trim();
      final expDateVal = widget.parsedMtsData?['expiry_date']?.toString().trim();
      final payload = {
        'import_file_id': _selectedImportFileId,
        'acid_number': acidToSave,
        if (genDateVal != null && genDateVal.isNotEmpty) 'generated_date': genDateVal,
        if (expDateVal != null && expDateVal.isNotEmpty) 'expiry_date': expDateVal,
        'importer_name': widget.parsedMtsData?['importer_name']?.toString().trim() ?? '',
        'importer_tax_id': widget.parsedMtsData?['importer_tax_id']?.toString().trim() ?? '',
        'exporter_name': widget.parsedMtsData?['exporter_name']?.toString().trim() ?? '',
        'exporter_reg_id': widget.parsedMtsData?['exporter_reg_id']?.toString().trim() ?? '',
        'exporter_country': widget.parsedMtsData?['exporter_country']?.toString().trim() ?? '',
        'proforma_invoice_no': widget.parsedMtsData?['proforma_invoice_no']?.toString().trim() ?? '',
        'pol_name': widget.parsedMtsData?['pol_name']?.toString().trim() ?? '',
        'pod_name': widget.parsedMtsData?['pod_name']?.toString().trim() ?? '',
        'status': 'Issued',
        'is_verified': true,
        'discrepancy_override_reason': _overrideReasonCtrl.text.trim(),
      };

      final sessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
      final existing = sessions.where((s) => s.importFileId == _selectedImportFileId && s.isActive).firstOrNull;

      if (existing != null) {
        await ref.read(acidSessionsProvider.notifier).updateAcidSession(existing.acidId, payload);
      } else {
        await ref.read(acidSessionsProvider.notifier).createAcidSession(payload);
      }

      await ref.read(importFilesProvider.notifier).fetchImportFiles();
      await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.acidCertifiedSuccess, severity: AppSeverity.success),
        );
        widget.onAcidCertified?.call();
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(context, title: l.errorCertifyingAcid, error: e);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Selector & Compare Trigger
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: AppTheme.cardDecorationOf(context),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SearchableDropdownField<int>(
                            labelText: l.selectImportFileAcidLabel,
                            hintText: l.searchFileOrSupplierHint,
                            value: _selectedImportFileId,
                            items: importFiles.map((f) => SearchableDropdownItem<int>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                            )).toList(),
                            onChanged: (val) {
                              setState(() => _selectedImportFileId = val);
                              widget.onImportFileChanged?.call(val);
                              if (val != null && widget.parsedMtsData != null) {
                                _runComparison();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: l.runDiscrepancyMatrixButton,
                            onPressed: _isComparing ? null : _runComparison,
                            icon: Icons.compare_arrows,
                            isLoading: _isComparing,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: SearchableDropdownField<int>(
                              labelText: l.selectImportFileAcidLabel,
                              hintText: l.searchFileOrSupplierHint,
                              value: _selectedImportFileId,
                              items: importFiles.map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode}${f.poNumber != null && f.poNumber!.isNotEmpty ? " [PO: ${f.poNumber!}]" : ""} — ${f.supplierName}',
                              )).toList(),
                              onChanged: (val) {
                                setState(() => _selectedImportFileId = val);
                                widget.onImportFileChanged?.call(val);
                                if (val != null && widget.parsedMtsData != null) {
                                  _runComparison();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          AppButton(
                            label: l.runDiscrepancyMatrixButton,
                            onPressed: _isComparing ? null : _runComparison,
                            icon: Icons.compare_arrows,
                            isLoading: _isComparing,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Empty state
              if (_comparisonResult == null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: Column(
                    children: [
                      Icon(Icons.rule_folder_outlined, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                      const SizedBox(height: 12),
                      Text(
                        l.emptyComparisonHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Discrepancy Matrix Checklist Table
              if (_comparisonResult != null) ...[
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderStatusRow(context, isMobile, isDark),
                      const Divider(height: 24),
                      _buildChecklistTable(context, constraints, isMobile, isDark),
                      const SizedBox(height: 20),

                      // Discrepancy Override Justification
                      if (!_comparisonResult!.allMatched) ...[
                        Text(
                          l.discrepancyOverrideJustificationLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.crimson,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _overrideReasonCtrl,
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          decoration: InputDecoration(
                            hintText: l.discrepancyOverrideReasonHint,
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action Button
                      AppButton(
                        label: _isSaving ? l.loading : l.verifyAndCertifyAcidButton,
                        onPressed: _isSaving ? null : _saveVerifiedAcid,
                        variant: AppButtonVariant.success,
                        icon: Icons.verified,
                        isLoading: _isSaving,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderStatusRow(BuildContext context, bool isMobile, bool isDark) {
    final l = context.l10n;
    final allMatched = _comparisonResult!.allMatched;

    final statusIcon = Icon(
      allMatched ? Icons.check_circle : Icons.warning_amber_rounded,
      color: allMatched
          ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
          : (isDark ? AppTheme.wcagOrange : AppTheme.crimson),
      size: 26,
    );

    final statusText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          allMatched ? l.perfectMatchTitle : l.discrepancyFoundTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: allMatched
                ? (isDark ? AppTheme.wcagEmerald : AppTheme.successForeground)
                : AppTheme.crimson,
          ),
        ),
        Text(
          '${l.matchingStatusCol}: ${_comparisonResult!.matchPercentage.toStringAsFixed(1)}% (${_comparisonResult!.matchedCount} / ${_comparisonResult!.totalComparedFields})',
          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        ),
      ],
    );

    final copyButton = AppButton(
      label: l.copyDiscrepancyReportBtn,
      onPressed: _copyDiscrepancyReport,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.small,
      icon: Icons.copy,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              statusIcon,
              const SizedBox(width: 10),
              Expanded(child: statusText),
            ],
          ),
          const SizedBox(height: 12),
          copyButton,
        ],
      );
    }

    return Row(
      children: [
        statusIcon,
        const SizedBox(width: 10),
        Expanded(child: statusText),
        const SizedBox(width: 12),
        copyButton,
      ],
    );
  }

  Widget _buildChecklistTable(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isDark,
  ) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth < 650 ? 650 : constraints.maxWidth - (isMobile ? 28 : 40),
        ),
        child: Table(
          border: TableBorder.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
            borderRadius: BorderRadius.circular(8),
          ),
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    l.customsFieldCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    l.requestedValueCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    l.generatedValueCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    l.matchingStatusCol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            ..._comparisonResult!.items.map((item) {
              return TableRow(
                decoration: BoxDecoration(
                  color: item.isMatched
                      ? (isDark ? AppTheme.darkCardBackground : AppTheme.surface)
                      : (isDark ? AppTheme.crimsonLight : AppTheme.dangerBackground.withValues(alpha: 0.5)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      isAr ? item.labelAr : item.labelEn,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: CopyableText(
                      item.requestedValue,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: CopyableText(
                      item.generatedValue,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          item.isMatched ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: item.isMatched
                              ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                              : AppTheme.crimson,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.isMatched ? l.matchedStatus : l.discrepancyStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.isMatched
                                  ? (isDark ? AppTheme.wcagEmerald : AppTheme.emerald)
                                  : AppTheme.crimson,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
