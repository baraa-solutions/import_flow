import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/export/widgets/export_language_dialog.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../models/supplier_model.dart';
import '../providers/suppliers_provider.dart';
import '../widgets/goeic_verification_dialog.dart';
import '../widgets/route_intelligence_dialog.dart';
import '../widgets/supplier_details_dialog.dart';
import '../widgets/supplier_form_dialog.dart';
import '../widgets/supplier_scorecard_dialog.dart';
import '../widgets/supplier_ledger_dialog.dart';
import '../widgets/suppliers_data_table.dart';
import '../widgets/suppliers_filter_toolbar.dart';

/// الشاشة الرئيسية المنسقة للموردين الأجانب
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleActive(SupplierModel supplier) async {
    final l10n = context.l10n;
    final isActive = supplier.isActive;
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: isActive,
      entityName: supplier.companyName,
      message: isActive
          ? l10n.confirmDeactivateSupplier(supplier.companyName)
          : l10n.confirmActivateSupplier(supplier.companyName),
    );
    if (confirm && supplier.supplierId != null) {
      await ref.read(suppliersProvider.notifier).toggleActiveStatus(supplier.supplierId!, isActive);
    }
  }

  Future<void> _handlePrint(SupplierModel supplier) async {
    final lang = await ExportLanguageDialog.show(context);
    if (lang != null) {
      await MasterDataExportService.printOrSaveSupplierPdf(supplier, lang: lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suppliersAsync = ref.watch(suppliersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.local_shipping_outlined,
        title: l10n.suppliersScreenTitle,
        subtitle: l10n.suppliersScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SuppliersFilterToolbar(
                searchController: _searchController,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                onAddSupplier: () => SupplierFormDialog.show(context),
                onExtractAi: () => UniversalEntityExtractorDialog.showSupplierExtractor(
                  context,
                  onSaved: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                ),
                onCopyTsv: () {
                  final list = suppliersAsync.valueOrNull;
                  if (list != null && list.isNotEmpty) {
                    SuppliersFilterToolbar.copySuppliersTsv(context, list);
                  }
                },
                onRefresh: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: suppliersAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, stack) => Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.crimson),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              l10n.suppliersFetchError(err.toString()),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.retryConnectionBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              ref.read(suppliersProvider.notifier).fetchSuppliers();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (suppliers) {
                    final filtered = suppliers.where((s) {
                      final q = _searchQuery;
                      return q.isEmpty ||
                          s.companyName.toLowerCase().contains(q) ||
                          s.supplierCode.toLowerCase().contains(q) ||
                          s.foreignExporterId.toLowerCase().contains(q) ||
                          s.foreignExporterCountry.toLowerCase().contains(q) ||
                          (s.brands?.toLowerCase().contains(q) ?? false);
                    }).toList();

                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        message: l10n.noSuppliersFound,
                        subtitle: _searchQuery.isNotEmpty ? '${l10n.noResultsFound}: $_searchQuery' : null,
                      );
                    }

                    return SuppliersDataTable(
                      suppliers: filtered,
                      onView: (s) => SupplierDetailsDialog.show(
                        context,
                        s,
                        onEdit: () => SupplierFormDialog.show(context, supplierToEdit: s),
                      ),
                      onEdit: (s) => SupplierFormDialog.show(context, supplierToEdit: s),
                      onPrint: _handlePrint,
                      onToggleActive: _handleToggleActive,
                      onRouteIntelligence: (s) {
                        showRouteIntelligenceDialog(
                          context,
                          ref,
                          supplierId: s.supplierId!,
                          supplierName: s.companyName,
                        );
                      },
                      onScorecard: (s) {
                        showSupplierScorecardDialog(
                          context,
                          ref,
                          supplierId: s.supplierId!,
                          supplierName: s.companyName,
                          country: s.foreignExporterCountry,
                        );
                      },
                      onLedger: (s) {
                        showSupplierLedgerDialog(
                          context,
                          supplierId: s.supplierId!,
                          supplierName: s.companyName,
                        );
                      },
                      onGoeicVerification: (s) {
                        showGOEICVerificationDialog(
                          context,
                          ref,
                          supplierId: s.supplierId!,
                          supplierName: s.companyName,
                        );
                      },
                      onHistory: (s) {
                        RowHistoryDialog.show(
                          context,
                          entityType: 'Supplier',
                          entityId: s.supplierId!,
                          entityTitle: s.companyName,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
