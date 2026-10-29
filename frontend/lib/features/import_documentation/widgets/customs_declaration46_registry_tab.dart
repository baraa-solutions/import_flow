import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/customs_declaration_assessment.dart';
import '../providers/import_documentation_provider.dart';
import '../services/customs_declaration46_calculator.dart';
import 'form46_figures_panel.dart';
import 'idoc_ui_b.dart';

class _DeclarationRegistryItem {
  final CustomsClearanceModel record;
  final ImportFileModel? file;
  final CustomsDeclarationAssessment? estimate;

  const _DeclarationRegistryItem({
    required this.record,
    required this.file,
    this.estimate,
  });

  String get declarationNo => record.declaration46No ?? '-';
  String get importFileCode => file?.importFileCode ?? (record.importFileId > 0 ? 'IMP-${record.importFileId}' : '-');
  String get primaryNameWithCode => file?.primaryNameWithCode ?? importFileCode;
  String get supplierName => file?.supplierName ?? '-';
  String get declarationDate => record.declaration46Date != null && record.declaration46Date!.length >= 10
      ? record.declaration46Date!.substring(0, 10)
      : '—';
  String get customsOffice => record.customsOfficeName.trim().isNotEmpty ? record.customsOfficeName : '—';
  String get channel => record.channelType;
  String get status => record.status;
  double? get effectiveDutyTotal => record.effectiveDutyTotal;
  double? get estimatedDutyTotal => estimate?.totalDutiesEgp;
}

class CustomsDeclaration46RegistryTab extends ConsumerStatefulWidget {
  final VoidCallback onRegisterNew;
  final ValueChanged<CustomsDeclarationAssessment> onCloneDeclaration;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefresh;

  const CustomsDeclaration46RegistryTab({
    super.key,
    required this.onRegisterNew,
    required this.onCloneDeclaration,
    required this.onOpenSearchAndClone,
    required this.onRefresh,
  });

  @override
  ConsumerState<CustomsDeclaration46RegistryTab> createState() => _CustomsDeclaration46RegistryTabState();
}

class _CustomsDeclaration46RegistryTabState extends ConsumerState<CustomsDeclaration46RegistryTab> {
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  Map<String, CustomsDeclarationAssessment> _cachedAssessments = {};
  int _lastInputsHash = 0;

  String get _miss => context.l10n.idocBMissing;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  CustomsDeclarationAssessment? _getOrComputeAssessment(
    ImportFileModel? file,
    AppLocalizations l, {
    required List<dynamic> acids,
    required List<dynamic> bankDocs,
    required List<dynamic> reviews,
    required List<dynamic> bookings,
    required List<CustomsTariffModel> allTariffs,
    required List<dynamic> pos,
    required List<CurrencyModel> currencies,
    String? declarationNo,
    String? registrationDate,
    String? status,
  }) {
    if (file == null) return null;
    final fileId = file.importFileId;
    final cacheKey = '$fileId|${declarationNo ?? file.form46No ?? ""}|${registrationDate ?? file.form46Date ?? ""}|${status ?? ""}';
    if (_cachedAssessments.containsKey(cacheKey)) {
      return _cachedAssessments[cacheKey];
    }
    final assessment = CustomsDeclarationAssessmentHelper.calculateAssessment(
      file,
      l,
      declarationNo: declarationNo ?? file.form46No ?? '',
      registrationDate: registrationDate ?? file.form46Date ?? '',
      status: status ?? '',
      cachedAcids: acids,
      cachedBankDocs: bankDocs,
      cachedReviews: reviews,
      cachedBookings: bookings,
      cachedTariffs: allTariffs,
      cachedPos: pos,
      cachedCurrencies: currencies,
    );
    _cachedAssessments[cacheKey] = assessment;
    return assessment;
  }

  Widget _figureText(double? value, Color color, {required bool bold}) {
    if (value == null) return IdocBMissingMark(label: _miss);
    return LtrText(
      '${IdocBFormat.money(value)} ${context.l10n.egpCurrency}',
      textAlign: TextAlign.end,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  void _showTariffAssessmentDialog(CustomsDeclarationAssessment a, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = l.isArabic;

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: IdocBDialogShell(
            title: l.customsDeclAssessmentTitle,
            subtitle: l.customsDeclAssessmentSubtitle,
            icon: Icons.analytics_outlined,
            badge: a.declarationNo,
            body: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!a.isComplete)
                    IdocBNotice(
                      key: const Key('assessmentMissingBanner'),
                      severity: AppSeverity.danger,
                      message: Form46FiguresPanel.missingItemsText(l, a.missing),
                    ),

                  // 1. Shipment particulars
                  IdocBSectionCard(
                    title: l.customsDeclShipmentParticularsHeader,
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(l.customsDeclColDeclarationNo, a.declarationNo, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclColFileNumber, a.primaryNameWithCode, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclColSupplier, a.supplierName, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclAcidNumberLabel, a.acidNumber, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclForm4NumberLabel, a.form4Number, isDark: isDark),
                        _buildAssessmentRow(l.customsDeclBlNumberLabel, a.blNumber, isDark: isDark),
                      ],
                    ),
                  ),

                  // 2. Valuation breakdown (CIF)
                  IdocBSectionCard(
                    title: l.customsDeclValuationBreakdownHeader,
                    icon: Icons.calculate_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(
                          l.customsDeclFobForeignLabel,
                          '${a.fobForeign.fixedOrMissing(2, _miss)} ${a.currency} (${a.fobEgp.egpOrMissing(_miss)})',
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          l.customsDeclFreightEgpLabel,
                          a.freightEgp.egpOrMissing(_miss),
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          l.customsDeclInsuranceEgpLabel,
                          a.insuranceEgp.egpOrMissing(_miss),
                          isDark: isDark,
                        ),
                        const Divider(),
                        _buildAssessmentRow(
                          l.customsDeclCifTotalEgpLabel,
                          a.cifEgp.egpOrMissing(_miss),
                          isBold: true,
                          valueColor: AppTheme.cobalt,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // 3. Tariff, duties and taxes
                  IdocBSectionCard(
                    title: l.customsDeclTariffTaxesHeader,
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(l.customsDeclColHsCode, '${a.hsCode} (${a.hsDescription})', isDark: isDark),
                        _buildAssessmentRow(
                          '${l.customsDeclImportDutyRateLabel} (${a.dutyRate.fixedOrMissing(1, _miss)}%)',
                          a.importDutyEgp.egpOrMissing(_miss),
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          '${l.customsDeclCustomsServicesFeeLabel} (${a.serviceRate.fixedOrMissing(1, _miss)}%)',
                          a.serviceFeeEgp.egpOrMissing(_miss),
                          isDark: isDark,
                        ),
                        if ((a.devRate ?? 0) > 0)
                          _buildAssessmentRow(
                            '${l.customsDeclDevFeeLabel} (${a.devRate.fixedOrMissing(1, _miss)}%)',
                            a.devFeeEgp.egpOrMissing(_miss),
                            isDark: isDark,
                          ),
                        _buildAssessmentRow(l.customsDeclVatBaseLabel, a.vatBaseEgp.egpOrMissing(_miss), isDark: isDark),
                        _buildAssessmentRow(
                          '${l.customsDeclVatRateLabel} (${a.vatRate.fixedOrMissing(1, _miss)}%)',
                          a.vatEgp.egpOrMissing(_miss),
                          isDark: isDark,
                        ),
                        const Divider(),
                        _buildAssessmentRow(
                          l.customsDeclTotalDutiesLabel,
                          a.totalDutiesEgp.egpOrMissing(_miss),
                          isBold: true,
                          valueColor: AppTheme.crimson,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // 4. Exemption status
                  IdocBSectionCard(
                    title: l.customsDeclExemptionHeader,
                    icon: a.hasExemption ? Icons.verified : Icons.info_outline,
                    accent: a.hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                    child: Row(
                      children: [
                        Icon(
                          a.hasExemption ? Icons.verified : Icons.info,
                          color: a.hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.exemptionTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBDialogAction(
                buttonKey: const Key('dialogCloneDeclBtn'),
                label: l.cloneCustomsDeclRowTooltip,
                icon: Icons.copy_all,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onCloneDeclaration(a);
                },
              ),
              IdocBDialogAction(
                label: l.customsDeclCloseDialog,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isCompact ? 130 : 200,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: CopyableText(
                  value,
                  isSelectable: false,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _copyRegistryTableTsv(List<_DeclarationRegistryItem> items, AppLocalizations l) {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.fixedOrMissing(2, _miss),
    ]).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportRegistryExcel(List<_DeclarationRegistryItem> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.fixedOrMissing(2, _miss),
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
    );
  }

  Future<void> _exportRegistryPdf(List<_DeclarationRegistryItem> items, AppLocalizations l) async {
    final headers = [
      l.customsDeclColDeclarationNo,
      l.customsDeclColFileNumber,
      l.customsDeclColSupplier,
      l.customsDeclColRegistrationDate,
      l.ccDecOfficeLabel,
      l.customsDeclChannelLabel,
      l.customsDeclColDeclarationStatus,
      l.customsDeclColTariffEstimate,
    ];

    final rows = items.map((a) => [
      a.declarationNo,
      a.importFileCode,
      a.supplierName,
      a.declarationDate,
      a.customsOffice,
      a.channel,
      a.status,
      a.estimatedDutyTotal.egpOrMissing(_miss),
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Customs Declarations 46 Registry',
      importFileNameOrCode: 'ALL-FILES',
      headerContext: TableExportHeaderContext(
        title: l.customsDeclTabRegistry,
        subtitle: l.customsDeclExportSubtitle,
        metadata: {
          l.customsDeclExportMetaTotal: items.length.toString(),
          l.customsDeclExportMetaGeneratedAt: DateTime.now().toString().substring(0, 19),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final clearanceAsync = ref.watch(customsClearanceProvider);
    final clearanceRecords = clearanceAsync.valueOrNull ?? [];
    final acids = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final bankDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];
    final reviews = ref.watch(draftBLReviewsProvider).valueOrNull ?? [];
    final bookings = ref.watch(freightBookingProvider).valueOrNull ?? [];
    final allTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
    final pos = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    final realDeclarations = clearanceRecords.where((r) {
      final no = r.declaration46No?.trim();
      return no != null && no.isNotEmpty;
    }).toList();

    final currentHash = Object.hash(
      identityHashCode(importFiles),
      identityHashCode(clearanceRecords),
      identityHashCode(acids),
      identityHashCode(bankDocs),
      identityHashCode(reviews),
      identityHashCode(bookings),
      identityHashCode(allTariffs),
      identityHashCode(pos),
      identityHashCode(currencies),
      l.isArabic,
    );
    if (_lastInputsHash != currentHash) {
      _lastInputsHash = currentHash;
      _cachedAssessments = {};
    }

    final fileMap = {for (final f in importFiles) f.importFileId: f};

    final allItems = realDeclarations.map((record) {
      final file = fileMap[record.importFileId];
      final estimate = _getOrComputeAssessment(
        file,
        l,
        acids: acids,
        bankDocs: bankDocs,
        reviews: reviews,
        bookings: bookings,
        allTariffs: allTariffs,
        pos: pos,
        currencies: currencies,
        declarationNo: record.declaration46No,
        registrationDate: record.declaration46Date,
        status: record.status,
      );
      return _DeclarationRegistryItem(
        record: record,
        file: file,
        estimate: estimate,
      );
    }).toList();

    final filteredItems = allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final dNo = item.declarationNo.toLowerCase();
      final fCode = item.importFileCode.toLowerCase();
      final supp = item.supplierName.toLowerCase();
      final pName = item.primaryNameWithCode.toLowerCase();
      final off = item.customsOffice.toLowerCase();
      return dNo.contains(q) ||
          fCode.contains(q) ||
          supp.contains(q) ||
          pName.contains(q) ||
          off.contains(q);
    }).toList();

    final totalCount = filteredItems.length;
    final totalStoredDuties = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.effectiveDutyTotal ?? 0.0),
    );
    final totalEstimatedDuties = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.estimatedDutyTotal ?? 0.0),
    );
    final totalExemptions = filteredItems.where((item) => item.estimate?.hasExemption == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI strip
        IdocBUi.metrics([
          MetricCardData(
            title: l.customsDeclMetricTotalDeclarations,
            value: totalCount.toString(),
            icon: Icons.assignment_turned_in_outlined,
            color: AppTheme.cobalt,
          ),
          MetricCardData(
            title: l.customsDeclMetricTotalDuties,
            value: '${IdocBFormat.money(totalStoredDuties)} ${l.egpCurrency}',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.crimson,
          ),
          MetricCardData(
            title: l.customsDeclMetricEstimatedDuties,
            value: '${IdocBFormat.money(totalEstimatedDuties)} ${l.egpCurrency}',
            icon: Icons.analytics_outlined,
            color: AppTheme.cobalt,
          ),
          MetricCardData(
            title: l.customsDeclMetricExemptions,
            value: totalExemptions.toString(),
            icon: Icons.verified_outlined,
            color: AppTheme.emerald,
          ),
        ]),
        const SizedBox(height: 18),

        // Search and Actions Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.customsDeclRegistrySearchHint,
                hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
                  if (mounted) setState(() => _searchQuery = val.trim());
                });
              },
            );

            final actionButtons = [
              AppButton(
                key: const Key('copyRegistryTableTsvBtn'),
                label: l.customsDeclExportTsvButton,
                onPressed: () => _copyRegistryTableTsv(filteredItems, l),
                variant: AppButtonVariant.secondary,
                icon: Icons.copy_all,
              ),
              AppButton(
                key: const Key('exportRegistryExcelBtn'),
                label: l.exportRegistryExcelTooltip,
                onPressed: () => _exportRegistryExcel(filteredItems, l),
                variant: AppButtonVariant.secondary,
                icon: Icons.table_view_outlined,
              ),
              AppButton(
                key: const Key('exportRegistryPdfBtn'),
                label: l.exportRegistryPdfTooltip,
                onPressed: () => _exportRegistryPdf(filteredItems, l),
                variant: AppButtonVariant.secondary,
                icon: Icons.picture_as_pdf_outlined,
              ),
              AppButton(
                key: const Key('registerNewDeclBtn'),
                label: l.customsDeclRegisterNewButton,
                onPressed: widget.onRegisterNew,
                icon: Icons.add,
              ),
            ];

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 260,
                    maxWidth: constraints.maxWidth < 600 ? constraints.maxWidth : 380,
                  ),
                  child: searchField,
                ),
                ...actionButtons,
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        if (filteredItems.isEmpty)
          IdocBStateView.empty(
            key: const Key('decl46RegistryEmpty'),
            message: _searchQuery.isNotEmpty
                ? l.idocBNoDeclarations
                : l.customsDeclRegistryEmptyMessage,
            icon: Icons.assignment_outlined,
            actionLabel: l.customsDeclRegisterNewButton,
            onAction: widget.onRegisterNew,
          )
        else
          Container(
            width: double.infinity,
            decoration: AppTheme.cardDecorationOf(context),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt),
                columns: [
                  DataColumn(
                    label: Text(
                      l.customsDeclColActions,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclColDeclarationNo,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclColFileNumber,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclColSupplier,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclColRegistrationDate,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.ccDecOfficeLabel,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclChannelLabel,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      l.customsDeclColDeclarationStatus,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(
                      l.customsDeclColTariffEstimate,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                ],
                rows: filteredItems.map((item) {
                  final rowSummary = '${item.declarationNo}\t${item.importFileCode}\t${item.supplierName}\t${item.declarationDate}\t${item.customsOffice}\t${item.channel}\t${item.status}\t${item.estimatedDutyTotal.fixedOrMissing(2, _miss)}';

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.estimate != null)
                              IconButton(
                                key: Key('viewAssessmentBtn_${item.declarationNo}'),
                                icon: const Icon(Icons.analytics_outlined, color: AppTheme.cobalt, size: 18),
                                tooltip: l.customsDeclViewAssessmentTooltip,
                                onPressed: () => _showTariffAssessmentDialog(item.estimate!, l),
                              ),
                            IconButton(
                              key: Key('copyRegistryRowBtn_${item.declarationNo}'),
                              icon: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
                              tooltip: l.copyRegistryRowSuccess,
                              onPressed: () {
                                final headers = [
                                  l.customsDeclColDeclarationNo,
                                  l.customsDeclColFileNumber,
                                  l.customsDeclColSupplier,
                                  l.customsDeclColRegistrationDate,
                                  l.ccDecOfficeLabel,
                                  l.customsDeclChannelLabel,
                                  l.customsDeclColDeclarationStatus,
                                  l.customsDeclColTariffEstimate,
                                ];
                                final values = [
                                  item.declarationNo,
                                  item.importFileCode,
                                  item.supplierName,
                                  item.declarationDate,
                                  item.customsOffice,
                                  item.channel,
                                  item.status,
                                  item.estimatedDutyTotal.fixedOrMissing(2, _miss),
                                ];
                                TableCopyHelper.copyRow(context, values, headers: headers);
                              },
                            ),
                            if (item.estimate != null)
                              IconButton(
                                key: Key('cloneRegistryRowBtn_${item.declarationNo}'),
                                icon: Icon(Icons.copy_all, size: 18, color: isDark ? AppTheme.emerald : AppTheme.flatEmerald),
                                tooltip: l.cloneCustomsDeclRowTooltip,
                                onPressed: () => widget.onCloneDeclaration(item.estimate!),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.declarationNo,
                          rowSummary: rowSummary,
                          child: Text(
                            item.declarationNo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.importFileCode,
                          rowSummary: rowSummary,
                          child: Text(
                            item.importFileCode,
                            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.supplierName,
                          rowSummary: rowSummary,
                          child: Text(
                            item.supplierName,
                            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.declarationDate,
                          rowSummary: rowSummary,
                          child: Text(
                            item.declarationDate,
                            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.customsOffice,
                          rowSummary: rowSummary,
                          child: Text(
                            item.customsOffice,
                            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.channel,
                          rowSummary: rowSummary,
                          child: Builder(
                            builder: (context) {
                              final ch = CcUi.channelStyle(l, item.channel);
                              return IdocBStatusChip(
                                label: ch.label,
                                severity: ch.severity,
                                icon: ch.icon,
                              );
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.status,
                          rowSummary: rowSummary,
                          child: Builder(
                            builder: (context) {
                              final st = CcUi.statusStyle(l, item.status);
                              return IdocBStatusChip(
                                label: st.label,
                                severity: st.severity,
                              );
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        CopyableTableCell(
                          value: item.estimatedDutyTotal.fixedOrMissing(2, _miss),
                          rowSummary: rowSummary,
                          child: _figureText(item.estimatedDutyTotal, AppTheme.crimson, bold: true),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
