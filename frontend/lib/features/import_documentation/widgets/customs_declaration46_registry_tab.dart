import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/metric_card.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/customs_declaration_assessment.dart';
import '../providers/import_documentation_provider.dart';
import 'customs_declaration46/declaration46_registry_table.dart';
import 'customs_declaration46/registry_export_helper.dart';
import 'customs_declaration46/registry_item.dart';
import 'customs_declaration46/tariff_assessment_dialog.dart';
import 'idoc_ui_b.dart';

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
      return DeclarationRegistryItem(
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

    return SelectionArea(
      child: Column(
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
                  onPressed: () => RegistryExportHelper.copyRegistryTableTsv(context, filteredItems, l),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.copy_all,
                ),
                AppButton(
                  key: const Key('exportRegistryExcelBtn'),
                  label: l.exportRegistryExcelTooltip,
                  onPressed: () => RegistryExportHelper.exportRegistryExcel(context, filteredItems, l),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.table_view_outlined,
                ),
                AppButton(
                  key: const Key('exportRegistryPdfBtn'),
                  label: l.exportRegistryPdfTooltip,
                  onPressed: () => RegistryExportHelper.exportRegistryPdf(context, filteredItems, l),
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
            Declaration46RegistryTable(
              items: filteredItems,
              isDark: isDark,
              onCloneDeclaration: widget.onCloneDeclaration,
              onShowAssessment: (assessment) {
                TariffAssessmentDialog.show(
                  context,
                  assessment: assessment,
                  l: l,
                  onCloneDeclaration: widget.onCloneDeclaration,
                );
              },
            ),
        ],
      ),
    );
  }
}
