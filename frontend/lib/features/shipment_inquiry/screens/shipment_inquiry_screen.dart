import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/widgets/import_file_details_dialog.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../providers/shipment_inquiry_provider.dart';
import '../services/shipment_inquiry_export_service.dart';
import '../widgets/inquiry/inquiry_columns_builder.dart';
import '../widgets/inquiry/inquiry_results_toolbar.dart';
import '../widgets/inquiry/inquiry_screen_header.dart';
import '../widgets/shipment_inquiry_filter_panel.dart';
import '../widgets/smart_insight_bar.dart';

class ShipmentInquiryScreen extends ConsumerStatefulWidget {
  const ShipmentInquiryScreen({super.key});

  @override
  ConsumerState<ShipmentInquiryScreen> createState() => _ShipmentInquiryScreenState();
}

class _ShipmentInquiryScreenState extends ConsumerState<ShipmentInquiryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(suppliersProvider.notifier).fetchSuppliers();
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    });
  }

  void _openDetails(ImportFileModel file) {
    showDialog(
      context: context,
      builder: (ctx) => ImportFileDetailsDialog(
        file: file,
        linkedPOs: const [],
        invoiceNumbers: const {},
        totalPackingListCbm: 0.0,
        totalPackingListWeight: 0.0,
        totalPackingListsCount: 0,
      ),
    );
  }

  void _openClone(ImportFileModel file) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arrowSymbol = DirectionalArrow.symbolForArabic(isAr);
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneImportFileDialogTitle,
      sourceCode: file.importFileCode,
      suggestedNewCode: '${file.importFileCode}-CLONE',
      sourceTitle: file.customFileNumber ?? file.companyName,
      copiedFieldsSummary: {
        l.importingCompany: file.companyName.isNotEmpty ? file.companyName : '-',
        l.foreignSupplier: file.supplierName.isNotEmpty ? file.supplierName : '-',
        l.portsOfLoadingAndDischarge: '${file.portOfLoading ?? '-'} $arrowSymbol ${file.portOfDischarge ?? '-'}',
        l.transportModeIncoterm: '${file.shipmentMode} (${file.incotermCode})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldCustomsClearedReset,
        l.cloneFieldFinancialReset,
        l.cloneFieldAcidReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        final cloned = await ref.read(importFilesProvider.notifier).cloneImportFile(
          file.importFileId,
          {
            'target_import_file_code': newCode.trim(),
            'new_import_file_code': newCode.trim(),
            'target_custom_file_number': newTitle.trim().isNotEmpty ? newTitle.trim() : null,
            'copy_invoices_data': copyLineItems,
            'copy_packing_lists': copyLineItems,
            'copy_items': copyLineItems,
            'copy_attachments': copyAttachments,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.clonedSuccessfullyToast(cloned?.importFileCode ?? newCode),
              severity: AppSeverity.success,
            ),
          );
        }
      },
    );
  }

  void _printSingleShipment(ImportFileModel file) {
    final user = ref.read(authProvider).user;
    final l = context.l10n;
    final username = user?.fullName ?? user?.username ?? l.inqOperatorManagerDefault;
    ShipmentInquiryExportService.printSingleShipmentSummary(
      context: context,
      file: file,
      username: username,
    );
  }

  String _buildFilterSummary(AppLocalizations l) {
    final filters = ref.read(shipmentInquiryStateProvider).filters;
    final parts = <String>[];
    if (filters.supplierId != null) parts.add('${l.inqSupplier}: ${filters.supplierId}');
    if (filters.companyId != null) parts.add('${l.inqImporter}: ${filters.companyId}');
    if (filters.hsCodeOrProduct.isNotEmpty) parts.add('${l.inqHsCodeOrProduct}: ${filters.hsCodeOrProduct}');
    if (filters.incotermCode != null && filters.incotermCode != 'All') {
      parts.add('${l.inqIncoterm}: ${filters.incotermCode}');
    }
    if (filters.portOfLoading != null && filters.portOfLoading!.isNotEmpty) {
      parts.add('${l.inqPortOfLoading}: ${filters.portOfLoading}');
    }
    if (filters.portOfDischarge != null && filters.portOfDischarge!.isNotEmpty) {
      parts.add('${l.inqPortOfDischarge}: ${filters.portOfDischarge}');
    }
    if (filters.shipmentMode != null && filters.shipmentMode != 'All') {
      parts.add('${l.inqShippingMode}: ${filters.shipmentMode}');
    }
    if (filters.carrier != null && filters.carrier!.isNotEmpty) {
      parts.add('${l.inqCarrier}: ${filters.carrier}');
    }
    if (filters.search.isNotEmpty) parts.add('${l.inqSearchPrefix}: ${filters.search}');

    return parts.isEmpty ? l.inqAllRegisteredShipments : parts.join(' | ');
  }

  void _handlePrintPdf() {
    final shipments = ref.read(filteredShipmentsProvider);
    final insights = ref.read(shipmentInquiryInsightsProvider);
    final user = ref.read(authProvider).user;
    final l = context.l10n;
    final username = user?.fullName ?? user?.username ?? l.inqOperatorManagerDefault;

    ShipmentInquiryExportService.printPdf(
      context: context,
      files: shipments,
      filterSummary: _buildFilterSummary(l),
      username: username,
      insights: insights,
    );
  }

  void _handleExportExcel() {
    final shipments = ref.read(filteredShipmentsProvider);
    ShipmentInquiryExportService.exportCsv(context: context, files: shipments);
  }

  void _handleExportTsv() {
    final shipments = ref.read(filteredShipmentsProvider);
    ShipmentInquiryExportService.exportTsv(context: context, files: shipments);
  }

  void _handleCopyDossier() {
    final shipments = ref.read(filteredShipmentsProvider);
    final l = context.l10n;
    ShipmentInquiryExportService.copyDossier(
      context: context,
      files: shipments,
      filterSummary: _buildFilterSummary(l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFilesAsync = ref.watch(importFilesProvider);
    final shipments = ref.watch(filteredShipmentsProvider);
    final stats = ref.watch(shipmentInquiryStatsProvider);
    final totalCount = stats['total_count'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SelectionArea(
        child: Column(
          children: [
            // Screen Header
            InquiryScreenHeader(
              onRefresh: () => ref.read(importFilesProvider.notifier).fetchImportFiles(),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: importFilesAsync.when(
                loading: () => const AppLoadingState(),
                error: (err, _) => Center(
                  child: Text('${l.inqLoadError}: $err', style: const TextStyle(color: AppTheme.crimson)),
                ),
                data: (_) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. Filter Panel (Matching Mockup)
                      ShipmentInquiryFilterPanel(
                        onSearch: () {
                          // Filter is already updated in provider
                        },
                        onExportPrint: _handlePrintPdf,
                      ),
                      const SizedBox(height: 16),

                      // 2. Smart Insight Bar
                      const SmartInsightBar(),
                      const SizedBox(height: 16),

                      // 3. Grid Table Header & Export Toolbar
                      InquiryResultsToolbar(
                        totalCount: totalCount,
                        onExportPdf: _handlePrintPdf,
                        onExportExcel: _handleExportExcel,
                        onExportTsv: _handleExportTsv,
                        onCopyDossier: _handleCopyDossier,
                      ),
                      const SizedBox(height: 12),

                      // 4. Interactive Shipments Grid
                      EnterpriseDataTable<ImportFileModel>(
                        storageKey: 'shipment_inquiry_grid',
                        data: shipments,
                        rowHeight: 56,
                        emptyMessage: l.inqEmptyShipmentsTitle,
                        emptyIcon: Icons.search_off_rounded,
                        onRowTap: _openDetails,
                        columns: InquiryColumnsBuilder.buildColumns(
                          context: context,
                          l: l,
                          onOpenDetails: _openDetails,
                          onOpenClone: _openClone,
                          onPrintSingleShipment: _printSingleShipment,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
