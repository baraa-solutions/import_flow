import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipping_scenarios/models/shipping_scenario_model.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import '../widgets/departure_confirmation_dialog.dart';
import '../widgets/search_and_clone_freight_booking_dialog.dart';
import '../../import_documentation/widgets/draft_bl_review_dialog.dart';
import '../../import_files/models/import_file_model.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class FreightBookingScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const FreightBookingScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<FreightBookingScreen> createState() => _FreightBookingScreenState();
}

class _FreightBookingScreenState extends ConsumerState<FreightBookingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  int? _selectedImportFileId;
  GuideMatchResultModel? _guideMatchResult;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      if (!ref.read(freightBookingProvider).isLoading) {
        ref.read(freightBookingProvider.notifier).fetchBookings(
          importFileId: _selectedImportFileId,
          status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
        );
      }
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (!ref.read(partnersProvider).isLoading) {
        ref.read(partnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(transportLocationsProvider).isLoading) {
        ref.read(transportLocationsProvider.notifier).fetchLocations();
      }
      if (!ref.read(shippingScenariosProvider).isLoading) {
        ref.read(shippingScenariosProvider.notifier).fetchSessions();
      }
      if (!ref.read(purchaseOrdersProvider).isLoading) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      if (!ref.read(currenciesProvider).isLoading) {
        ref.read(currenciesProvider.notifier).fetchCurrencies();
      }
      if (_selectedImportFileId != null) {
        _loadGuideForFile(_selectedImportFileId);
      }
    });
  }

  Future<void> _loadGuideForFile(int? fileId) async {
    if (fileId == null) {
      if (mounted) setState(() => _guideMatchResult = null);
      return;
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file != null) {
      try {
        final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
          supplier: file.supplierName,
          hsCode: file.hsCode,
          productCategory: file.productCategory,
          portOfDischarge: file.portOfDischarge,
          incoterm: file.incotermCode,
          importFileReference: file.importFileCode,
        );
        if (mounted) {
          setState(() => _guideMatchResult = res);
        }
      } catch (_) {}
    }
  }

  void _refreshData() {
    ref.read(freightBookingProvider.notifier).fetchBookings(
      importFileId: _selectedImportFileId,
      status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
    );
    ref.read(shippingScenariosProvider.notifier).fetchSessions();
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditBookingDialog([ShipmentBookingModel? bookingToEdit]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FreightBookingFormDialog(bookingToEdit: bookingToEdit),
    );
  }

  void _showViewBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => _FreightBookingViewDialog(booking: booking),
    );
  }

  void _showPrintBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => _FreightBookingPrintDialog(booking: booking),
    );
  }

  void _showConfirmBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FreightBookingConfirmDialog(booking: booking),
    );
  }

  void _showDepartureConfirmationDialog(ShipmentBookingModel booking) {
    DepartureConfirmationDialog.show(context, booking);
  }

  void _showDraftBlReviewDialog(ShipmentBookingModel booking) {
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFile = files.where((f) => f.importFileId == booking.importFileId).firstOrNull;
    final file = matchingFile ??
        ImportFileModel(
          importFileId: booking.importFileId ?? 0,
          importFileCode: booking.importFileCode ?? 'IMP-${booking.bookingCode}',
          companyName: '',
          supplierName: '',
          currentModule: 'ImportFiles',
          currentStage: 'Phase 5 - Sailing & CargoX',
          nextAction: 'Review Draft BL',
          createdAt: '',
          updatedAt: '',
        );
    DraftBLReviewDialog.show(context, file);
  }

  void _openSearchAndCloneDialog(List<ShipmentBookingModel> bookings) {
    final isAr = AppLocalizations.of(context).isArabic;
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: SearchAndCloneFreightBookingDialog(
            bookings: bookings,
            onSelectBooking: (selected) => _onCloneBooking(selected),
          ),
        ),
      ),
    );
  }

  void _onCloneBooking(ShipmentBookingModel booking) {
    final l = AppLocalizations.of(context);
    final isAr = l.isArabic;
    final newDraftCode = 'BK-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: isAr ? 'حجز شحن بحري / جوي' : 'Freight Booking',
            sourceCode: booking.bookingCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: '${booking.shippingLineName ?? "—"} (${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"})',
            copiedFieldsSummary: {
              isAr ? 'الخط الملاحي / الوكيل' : 'Carrier / Forwarder': '${booking.shippingLineName ?? "—"} / ${booking.freightForwarderName ?? "—"}',
              isAr ? 'خط السير' : 'Route': '${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"}',
              isAr ? 'تخصيص الحاويات' : 'Allocated Containers': booking.containersData.map((c) => "${c.quantity}x ${c.containerType}").join(", "),
              isAr ? 'إجمالي النولون التقديري' : 'Total Freight': '\$${booking.totalFreightCostUsd.toStringAsFixed(2)} USD',
            },
            mandatorilyResetFields: isAr
                ? const [
                    'رقم تأكيد الحجز (Confirmation No): يتم تفريغه للمسودة الجديدة',
                    'اسم السفينة ورقم الرحلة (Vessel & Voyage): يتطلب إعادة تأكيد',
                    'تاريخ المغادرة الفعلي (ATD): غير محدد للمسودة الجديدة',
                    'حالة الحجز: تعاد إلى مسودة قيد الإعداد (Draft)',
                  ]
                : const [
                    'Booking Confirmation No: Cleared for new draft',
                    'Vessel & Voyage: Cleared for re-allocation',
                    'Actual Time of Departure (ATD): Cleared',
                    'Booking Status: Reset to Draft',
                  ],
            allowCopyLineItems: true,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final cloned = ShipmentBookingModel(
                bookingId: 0,
                bookingCode: newCode,
                bookingConfirmationNo: '',
                importFileId: booking.importFileId,
                importFileCode: booking.importFileCode,
                shippingLineId: booking.shippingLineId,
                shippingLineName: booking.shippingLineName,
                freightForwarderId: booking.freightForwarderId,
                freightForwarderName: booking.freightForwarderName,
                polLocationId: booking.polLocationId,
                polName: booking.polName,
                podLocationId: booking.podLocationId,
                podName: booking.podName,
                vesselName: booking.vesselName,
                voyageNumber: booking.voyageNumber,
                etd: booking.etd,
                eta: booking.eta,
                atd: null,
                expectedWarehouseArrivalDate: null,
                containersData: copyLineItems ? booking.containersData : [],
                costChargesData: copyLineItems ? booking.costChargesData : [],
                totalFreightCostUsd: booking.totalFreightCostUsd,
                status: 'Draft',
                departureDelayDays: 0,
                isActive: true,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l.cloneBookingRowTooltip}: $newCode'),
                    backgroundColor: AppTheme.cobalt,
                  ),
                );

                _showAddEditBookingDialog(cloned);
              }
            },
          ),
        ),
      ),
    );
  }

  void _copyBookingRowTsv(ShipmentBookingModel bkg, AppLocalizations l) {
    final rowData = [
      bkg.bookingCode,
      bkg.importFileCode ?? '',
      bkg.bookingConfirmationNo ?? '',
      bkg.shippingLineName ?? '',
      bkg.freightForwarderName ?? '',
      bkg.polName ?? '',
      bkg.podName ?? '',
      bkg.vesselName ?? '',
      bkg.voyageNumber ?? '',
      bkg.etd != null && bkg.etd!.length >= 10 ? bkg.etd!.substring(0, 10) : '',
      bkg.eta != null && bkg.eta!.length >= 10 ? bkg.eta!.substring(0, 10) : '',
      bkg.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
      bkg.totalFreightCostUsd.toStringAsFixed(2),
      bkg.status,
    ];
    final headers = [
      l.freightBookingColBookingCode,
      l.freightBookingColImportFile,
      l.freightBookingColConfirmationNo,
      l.freightBookingShippingLineLabel,
      l.freightBookingForwarderLabel,
      l.freightBookingPolLabel,
      l.freightBookingPodLabel,
      l.freightBookingVesselNameInput,
      l.freightBookingVoyageNoInput,
      l.freightBookingEtdLabel,
      l.freightBookingEtaLabel,
      l.freightBookingColContainers,
      l.freightBookingColTotalFreight,
      l.freightBookingColStatus,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyBookingRowSuccess,
    );
  }

  void _copyBookingsTableTsv(List<ShipmentBookingModel> bookings, AppLocalizations l) {
    final headers = [
      l.freightBookingColBookingCode,
      l.freightBookingColImportFile,
      l.freightBookingColConfirmationNo,
      l.freightBookingShippingLineLabel,
      l.freightBookingForwarderLabel,
      l.freightBookingPolLabel,
      l.freightBookingPodLabel,
      l.freightBookingVesselNameInput,
      l.freightBookingVoyageNoInput,
      l.freightBookingEtdLabel,
      l.freightBookingEtaLabel,
      l.freightBookingColContainers,
      l.freightBookingColTotalFreight,
      l.freightBookingColStatus,
    ];
    final rows = bookings.map((b) => [
      b.bookingCode,
      b.importFileCode ?? '',
      b.bookingConfirmationNo ?? '',
      b.shippingLineName ?? '',
      b.freightForwarderName ?? '',
      b.polName ?? '',
      b.podName ?? '',
      b.vesselName ?? '',
      b.voyageNumber ?? '',
      b.etd != null && b.etd!.length >= 10 ? b.etd!.substring(0, 10) : '',
      b.eta != null && b.eta!.length >= 10 ? b.eta!.substring(0, 10) : '',
      b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
      b.totalFreightCostUsd.toStringAsFixed(2),
      b.status,
    ]).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyBookingsTableSuccess,
    );
  }

  Future<void> _exportBookingsExcel(List<ShipmentBookingModel> bookings, AppLocalizations l) async {
    final headers = [
      l.freightBookingColBookingCode,
      l.freightBookingColImportFile,
      l.freightBookingColConfirmationNo,
      l.freightBookingShippingLineLabel,
      l.freightBookingForwarderLabel,
      l.freightBookingPolLabel,
      l.freightBookingPodLabel,
      l.freightBookingVesselNameInput,
      l.freightBookingVoyageNoInput,
      l.freightBookingEtdLabel,
      l.freightBookingEtaLabel,
      l.freightBookingColContainers,
      l.freightBookingColTotalFreight,
      l.freightBookingColStatus,
    ];
    final rows = bookings.map((b) => [
      b.bookingCode,
      b.importFileCode ?? '',
      b.bookingConfirmationNo ?? '',
      b.shippingLineName ?? '',
      b.freightForwarderName ?? '',
      b.polName ?? '',
      b.podName ?? '',
      b.vesselName ?? '',
      b.voyageNumber ?? '',
      b.etd != null && b.etd!.length >= 10 ? b.etd!.substring(0, 10) : '',
      b.eta != null && b.eta!.length >= 10 ? b.eta!.substring(0, 10) : '',
      b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
      b.totalFreightCostUsd.toStringAsFixed(2),
      b.status,
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Freight Booking',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportBookingsPdf(List<ShipmentBookingModel> bookings, AppLocalizations l) async {
    final headers = [
      l.freightBookingColBookingCode,
      l.freightBookingColConfirmationNo,
      l.freightBookingShippingLineLabel,
      l.freightBookingColRoute,
      l.freightBookingColContainers,
      l.freightBookingColTotalFreight,
      l.freightBookingColStatus,
    ];
    final rows = bookings.map((b) => [
      b.bookingCode,
      b.bookingConfirmationNo ?? '—',
      b.shippingLineName ?? '—',
      '${b.polName ?? "-"} -> ${b.podName ?? "-"}',
      b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', '),
      '\$${b.totalFreightCostUsd.toStringAsFixed(2)}',
      b.status,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Freight Booking',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: 'Freight Bookings Registry',
        subtitle: 'Sorour Logistics ERP — سجل حجوزات الشحن والناقلين',
        metadata: {
          'Total Bookings': bookings.length.toString(),
          'Confirmed': bookings.where((b) => b.status == 'Confirmed').length.toString(),
          'Total USD': '\$${bookings.fold(0.0, (acc, b) => acc + b.totalFreightCostUsd).toStringAsFixed(2)}',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isAr = l.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookingsState = ref.watch(freightBookingProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.directions_boat_outlined,
        titleEn: 'Freight Bookings Registry',
        titleAr: 'سجل حجوزات الشحن والناقلين',
      ),
      const VerticalNavTabItem(
        icon: Icons.add_task_outlined,
        titleEn: 'New Booking Request',
        titleAr: 'طلب حجز شحن جديد',
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-3: STEP_07',
      titleEn: 'Freight Booking & Carrier Allocation',
      titleAr: 'حجز الشحن وتخصيص الحاويات',
      headerIcon: Icons.directions_boat,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (index) {
        if (index == 1) {
          _showAddEditBookingDialog();
        }
      },
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: _refreshData,
      headerActions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.directions_boat_rounded, size: 16),
          label: Text(l.freightBookingAiShippingLineBtn),
          onPressed: () => UniversalEntityExtractorDialog.showShippingLineExtractor(
            context,
            onSaved: () {
              ref.read(partnersProvider.notifier).fetchPartners();
              ref.read(allPartnersProvider.notifier).fetchPartners();
            },
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping_rounded, size: 16),
          label: Text(l.freightBookingAiForwarderBtn),
          onPressed: () => UniversalEntityExtractorDialog.showFreightForwarderExtractor(
            context,
            onSaved: () {
              ref.read(partnersProvider.notifier).fetchPartners();
              ref.read(allPartnersProvider.notifier).fetchPartners();
            },
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          tooltip: l.freightBookingBtnLiveReload,
          onPressed: _refreshData,
        ),
      ],
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data Actions Toolbar
            MasterDataToolbarWidget(
              moduleEndpoint: 'freight-booking',
              title: 'Freight_Bookings',
              onRefreshNeeded: () => ref.read(freightBookingProvider.notifier).fetchBookings(),
            ),
            const SizedBox(height: 12),

            // Top Toolbar
            Card(
              elevation: 2,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 1100;
                    final bookings = bookingsState.valueOrNull ?? [];
                    final actionButtons = [
                      ElevatedButton.icon(
                        key: const Key('createBookingBtn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showAddEditBookingDialog(),
                        icon: const Icon(Icons.add_task, size: 18),
                        label: Text(
                          l.freightBookingCreateButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('searchAndCloneBookingBtn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF93C5FD) : AppTheme.cobalt,
                          side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _openSearchAndCloneDialog(bookings),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: Text(
                          l.searchAndCloneFreightBookingBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('copyBookingsTableTsvBtn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF93C5FD) : AppTheme.cobalt,
                          side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _copyBookingsTableTsv(bookings, l),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(l.customsDeclExportTsvButton, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        key: const Key('exportBookingsExcelBtn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF6EE7B7) : AppTheme.flatEmerald,
                          side: BorderSide(color: isDark ? const Color(0xFF10B981) : AppTheme.flatEmerald),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _exportBookingsExcel(bookings, l),
                        icon: const Icon(Icons.table_view_outlined, size: 16),
                        label: Text(l.exportBookingsExcelTooltip, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        key: const Key('exportBookingsPdfBtn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFFFCA5A5) : AppTheme.crimson,
                          side: BorderSide(color: isDark ? const Color(0xFFEF4444) : AppTheme.crimson),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _exportBookingsPdf(bookings, l),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: Text(l.exportBookingsPdfTooltip, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ];

                    final searchAndFilter = [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 180,
                          maxWidth: isNarrow ? constraints.maxWidth : 260,
                        ),
                        child: TextField(
                          key: const Key('bookingSearchField'),
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l.freightBookingSearchHint,
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
                            prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                            isDense: true,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                            ),
                          ),
                          style: TextStyle(color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                          onChanged: (val) {
                            ref.read(freightBookingProvider.notifier).fetchBookings(search: val, status: _selectedStatusFilter);
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 180,
                          maxWidth: isNarrow ? constraints.maxWidth : 220,
                        ),
                        child: SearchableDropdownField<String>(
                          value: _selectedStatusFilter,
                          labelText: l.freightBookingFilterStatusLabel,
                          searchHintText: l.freightBookingFilterStatusHint,
                          items: [
                            SearchableDropdownItem(value: 'All', label: l.freightBookingStatusAll),
                            SearchableDropdownItem(value: 'Draft', label: l.freightBookingStatusDraft),
                            SearchableDropdownItem(value: 'Booking Requested', label: l.freightBookingStatusRequested),
                            SearchableDropdownItem(value: 'Confirmed', label: l.freightBookingStatusConfirmed),
                            SearchableDropdownItem(value: 'Sailed', label: l.freightBookingStatusSailed),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatusFilter = val);
                              ref.read(freightBookingProvider.notifier).fetchBookings(search: _searchController.text, status: val);
                            }
                          },
                        ),
                      ),
                      if (_selectedImportFileId != null)
                        InputChip(
                          avatar: const Icon(Icons.filter_alt, size: 16, color: AppTheme.cobalt),
                          label: Text(isAr ? 'تصفية: شحنة #$_selectedImportFileId' : 'Filter: Shipment #$_selectedImportFileId'),
                          onDeleted: () {
                            setState(() => _selectedImportFileId = null);
                            ref.read(freightBookingProvider.notifier).fetchBookings(
                                  search: _searchController.text,
                                  status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
                                );
                          },
                        ),
                    ];

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        ...actionButtons,
                        ...searchAndFilter,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Smart Experience Guide Alert Banner
            if (_guideMatchResult != null && _guideMatchResult!.matchedEntries.isNotEmpty)
              ExperienceGuideAlertBanner(
                matchResult: _guideMatchResult!,
              ),

            // Master DataTable
            bookingsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('❌ Error: $err', style: const TextStyle(color: Colors.red))),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return Center(
                      child: Text(l.freightBookingEmptyRecords, style: const TextStyle(fontSize: 16)),
                    );
                  }
                  return Card(
                    elevation: 2,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : AppTheme.charcoal.withOpacity(0.06)),
                          horizontalMargin: 12,
                          columnSpacing: 16,
                          columns: [
                            DataColumn(label: Text(l.freightBookingColActions, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColBookingCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColImportFile, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColConfirmationNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColCarrierForwarder, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColRoute, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColVesselVoyage, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColDeparture, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColArrival, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColContainers, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColTotalFreight, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(l.freightBookingColStatus, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: bookings.map((bkg) {
                            final hasDelay = bkg.departureDelayDays > 0;
                            return DataRow(
                              cells: [
                                // 1. Operations Pill in Column 1
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RowActionsPill(
                                        onView: () => _showViewBookingDialog(bkg),
                                        onEdit: () => _showAddEditBookingDialog(bkg),
                                        onClone: () => _onCloneBooking(bkg),
                                        onPrint: () => _showPrintBookingDialog(bkg),
                                        onDelete: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: Text(l.freightBookingDeleteConfirmTitle),
                                              content: Text(l.freightBookingDeleteConfirmMessage(bkg.bookingCode)),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: Text(l.delete),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await ref.read(freightBookingProvider.notifier).softDeleteBooking(bkg.bookingId);
                                          }
                                        },
                                        viewTooltip: l.freightBookingViewTooltip,
                                        editTooltip: l.freightBookingEditTooltip,
                                        cloneTooltip: l.cloneBookingRowTooltip,
                                        printTooltip: l.freightBookingPrintTooltip,
                                        deleteTooltip: l.freightBookingDeleteTooltip,
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        key: Key('copyBookingRowBtn_${bkg.bookingCode}'),
                                        icon: const Icon(Icons.copy, size: 16),
                                        tooltip: l.copyBookingRowSuccess,
                                        onPressed: () => _copyBookingRowTsv(bkg, l),
                                      ),
                                      IconButton(
                                        key: Key('cloneBookingRowBtn_${bkg.bookingCode}'),
                                        icon: const Icon(Icons.copy_all_rounded, size: 16, color: AppTheme.cobalt),
                                        tooltip: l.cloneBookingRowTooltip,
                                        onPressed: () => _onCloneBooking(bkg),
                                      ),
                                      if (bkg.status != 'Confirmed' && bkg.status != 'Sailed')
                                        IconButton(
                                          key: Key('confirmBookingRowBtn_${bkg.bookingCode}'),
                                          icon: const Icon(Icons.verified_outlined, size: 16, color: AppTheme.emerald),
                                          tooltip: isAr
                                              ? 'تأكيد الحجز ومواعيد الإبحار (BK-01)'
                                              : 'Confirm Booking & Sailing Schedule (BK-01)',
                                          onPressed: () => _showConfirmBookingDialog(bkg),
                                        ),
                                      if (bkg.status == 'Confirmed')
                                        IconButton(
                                          key: Key('confirmDepartureRowBtn_${bkg.bookingCode}'),
                                          icon: const Icon(Icons.sailing_rounded, size: 16, color: AppTheme.cobalt),
                                          tooltip: isAr
                                              ? 'تأكيد الإبحار الفعلي وإصدار بوليصة الشحن (SH-01)'
                                              : 'Confirm Actual Sailing & Issue B/L (SH-01)',
                                          onPressed: () => _showDepartureConfirmationDialog(bkg),
                                        ),
                                      if (bkg.status == 'Sailed') ...[
                                        IconButton(
                                          key: Key('viewDepartureRowBtn_${bkg.bookingCode}'),
                                          icon: const Icon(Icons.receipt_long, size: 16, color: AppTheme.emerald),
                                          tooltip: isAr
                                              ? 'تحديث بوليصة الشحن والإبحار (SH-01)'
                                              : 'Update Bill of Lading & Sailing (SH-01)',
                                          onPressed: () => _showDepartureConfirmationDialog(bkg),
                                        ),
                                        IconButton(
                                          key: Key('reviewDraftBlRowBtn_${bkg.bookingCode}'),
                                          icon: const Icon(Icons.fact_check_rounded, size: 16, color: Color(0xFF059669)),
                                          tooltip: isAr
                                              ? 'مراجعة مسودة البوليصة والاعتماد المزدوج (SH-02)'
                                              : 'Review Draft B/L & Dual Approval (SH-02)',
                                          onPressed: () => _showDraftBlReviewDialog(bkg),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // 2. Booking Code (Clickable Badge)
                                DataCell(
                                  InkWell(
                                    onTap: () => _showViewBookingDialog(bkg),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.cobalt.withOpacity(0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!bkg.isActive)
                                            const Padding(
                                              padding: EdgeInsetsDirectional.only(end: 4),
                                              child: Icon(Icons.block, size: 12, color: AppTheme.crimson),
                                            ),
                                          LtrText(
                                            bkg.bookingCode,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: bkg.isActive ? AppTheme.cobalt : AppTheme.crimson,
                                              fontSize: 12,
                                              decoration: bkg.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Linked Import File
                                DataCell(
                                  Builder(
                                    builder: (context) {
                                      final f = bkg.importFileId != null ? importFilesMap[bkg.importFileId] : null;
                                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                      final rawCode = bkg.importFileCode ?? (bkg.importFileId != null ? 'IMP-${bkg.importFileId}' : '');
                                      final shipName = f != null
                                          ? DisplayNameResolver.resolveShipmentName(f, isArabic: isAr)
                                          : DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isAr);
                                      final shipTitle = f != null
                                          ? DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr)
                                          : DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);

                                      return CopyableTableCell(
                                        value: shipTitle,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              shipName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (rawCode.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(top: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cobalt.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  rawCode,
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // 4. Confirmation No & Bill of Lading
                                DataCell(CopyableTableCell(
                                  value: bkg.billOfLadingNo != null
                                      ? '${bkg.bookingConfirmationNo ?? "-"}\nB/L: ${bkg.billOfLadingNo}'
                                      : (bkg.bookingConfirmationNo ?? l.freightBookingDraftPendingLabel),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bkg.bookingConfirmationNo ?? l.freightBookingDraftPendingLabel,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      if (bkg.billOfLadingNo != null)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emerald.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.receipt_long, size: 10, color: AppTheme.emerald),
                                              const SizedBox(width: 3),
                                              Text(
                                                'B/L: ${bkg.billOfLadingNo}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.emerald,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                )),

                                // 5. Shipping Line / Forwarder
                                DataCell(CopyableTableCell(
                                  value: '${bkg.shippingLineName ?? "-"} / ${bkg.freightForwarderName ?? "-"}',
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(bkg.shippingLineName ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      if (bkg.scenarioProviderName != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified, size: 11, color: AppTheme.emerald),
                                            const SizedBox(width: 2),
                                            Text(
                                              l.freightBookingApprovedQuoteLabel(bkg.scenarioProviderName!),
                                              style: const TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(l.freightBookingForwarderPrefixLabel(bkg.freightForwarderName ?? '—'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                )),

                                // 6. POL ➔ POD
                                DataCell(CopyableTableCell(
                                  value: '${bkg.polName ?? "-"} → ${bkg.podName ?? "-"}',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.cobalt),
                                      const SizedBox(width: 3),
                                      Text('${bkg.polName ?? "—"} ➔ ${bkg.podName ?? "—"}', style: const TextStyle(fontSize: 11.5)),
                                    ],
                                  ),
                                )),

                                // 7. Vessel & Voyage
                                DataCell(CopyableTableCell(
                                  value: '${bkg.vesselName ?? "-"} / ${bkg.voyageNumber ?? "-"}',
                                  child: Text('${bkg.vesselName ?? "—"} (${bkg.voyageNumber ?? "—"})', style: const TextStyle(fontSize: 11.5)),
                                )),

                                // 8. Departure (ETD / ATD)
                                DataCell(CopyableTableCell(
                                  value: '${l.freightBookingEtdPrefixLabel(bkg.etd != null ? bkg.etd!.substring(0, 10) : "-")}${bkg.atd != null ? " | ${l.freightBookingAtdPrefixLabel(bkg.atd!.substring(0, 10))}" : ""}',
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.freightBookingEtdPrefixLabel(bkg.etd != null ? bkg.etd!.substring(0, 10) : '—'), style: const TextStyle(fontSize: 11)),
                                      if (bkg.atd != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(l.freightBookingAtdPrefixLabel(bkg.atd!.substring(0, 10)), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            if (hasDelay) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                                child: Text('+${bkg.departureDelayDays}d', style: TextStyle(fontSize: 9, color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                )),

                                // 9. Arrival (ETA / WH)
                                DataCell(CopyableTableCell(
                                  value: l.freightBookingEtaPrefixLabel(bkg.eta != null ? bkg.eta!.substring(0, 10) : '-'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.freightBookingEtaPrefixLabel(bkg.eta != null ? bkg.eta!.substring(0, 10) : '—'), style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11)),
                                      if (bkg.expectedWarehouseArrivalDate != null)
                                        Text(l.freightBookingWhArrivalLabel(bkg.expectedWarehouseArrivalDate!.substring(0, 10)), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                    ],
                                  ),
                                )),

                                // 10. Allocated Containers
                                DataCell(CopyableTableCell(
                                  value: bkg.containersData.isNotEmpty
                                      ? bkg.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
                                      : '—',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      bkg.containersData.isNotEmpty
                                          ? bkg.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
                                          : '—',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )),

                                // 11. Total Freight USD
                                DataCell(CopyableTableCell(
                                  value: '\$ ${bkg.totalFreightCostUsd.toStringAsFixed(2)}',
                                  child: Text(
                                    '\$ ${bkg.totalFreightCostUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 12),
                                  ),
                                )),

                                // 12. Status Pill
                                DataCell(CopyableTableCell(
                                  value: bkg.status,
                                  child: Tooltip(
                                    message: bkg.status == 'Confirmed'
                                        ? 'الحجز مؤكد — انقر لتأكيد الإبحار وبوليصة الشحن (SH-01)'
                                        : (bkg.status == 'Sailed'
                                            ? 'أبحرت الشحنة (B/L: ${bkg.billOfLadingNo ?? "-"}) — انقر لتحديث البيانات'
                                            : 'انقر لتأكيد الحجز وتثبيت المواعيد (BK-01)'),
                                    child: InkWell(
                                      onTap: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                                          ? () => _showDepartureConfirmationDialog(bkg)
                                          : () => _showConfirmBookingDialog(bkg),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                                              ? AppTheme.emerald.withOpacity(0.15)
                                              : AppTheme.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                                                ? AppTheme.emerald.withOpacity(0.4)
                                                : AppTheme.orange.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (bkg.status != 'Confirmed')
                                              const Padding(
                                                padding: EdgeInsetsDirectional.only(start: 3),
                                                child: Icon(Icons.touch_app, size: 12, color: AppTheme.orange),
                                              ),
                                            Text(
                                              bkg.status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: bkg.status == 'Confirmed' || bkg.status == 'Sailed'
                                                    ? AppTheme.emerald
                                                    : AppTheme.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )),
                              ],

                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreightBookingFormDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel? bookingToEdit;
  const _FreightBookingFormDialog({this.bookingToEdit});

  @override
  ConsumerState<_FreightBookingFormDialog> createState() => _FreightBookingFormDialogState();
}

class _FreightBookingFormDialogState extends ConsumerState<_FreightBookingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bookingConfirmNoController;
  late TextEditingController _polController;
  late TextEditingController _podController;
  late TextEditingController _vesselNameController;
  late TextEditingController _voyageNoController;
  late TextEditingController _releaseOrderNoController;
  late TextEditingController _freeDemurrageController;
  late TextEditingController _expectedWhDaysController;
  late TextEditingController _ownerController;
  late TextEditingController _notesController;

  int? _selectedImportFileId;
  int? _selectedScenarioSessionId;
  int? _selectedScenarioItemId;
  String? _selectedScenarioProviderName;

  String _shipmentType = 'Ocean FCL';
  String _freightTerms = 'Collect';
  String _status = 'Draft';
  String _shippingLineName = 'Mediterranean Shipping Company (MSC)';
  String _freightForwarderName = 'El-Ahram Logistics';

  DateTime _etd = DateTime.now().add(const Duration(days: 5));
  DateTime _eta = DateTime.now().add(const Duration(days: 23));
  DateTime? _atd;
  String? _containerMismatchReason;

  final bool _isStackable = true;
  List<ContainerAllocationModel> _containers = [];
  List<BookingChargeModel> _charges = [];

  // Full 17 quote items state matching Phase 1
  String _mainQuoteCurrency = 'USD';
  double? _originalQuoteTotalUsd;
  double? _originalContainer40ftPrice;
  double? _originalContainer20ftPrice;
  double? _originalLclCbmPrice;
  double? _originalExpressCourierPrice;

  bool _container40ftApp = true;
  double _container40ftPrice = 8500.0;
  String _container40ftCur = 'USD';
  int _container40ftQty = 1;

  bool _container20ftApp = false;
  double _container20ftPrice = 0.0;
  String _container20ftCur = 'USD';
  int _container20ftQty = 0;

  bool _lclCbmApp = false;
  double _lclCbmPrice = 0.0;
  String _lclCbmCur = 'USD';
  double _lclCbmQty = 0.0;

  bool _expressCourierApp = false;
  double _expressCourierPrice = 0.0;
  String _expressCourierCur = 'USD';

  bool _eurAtrApp = false;
  double _eurAtrPrice = 0.0;
  String _eurAtrCur = 'USD';

  bool _solasVgmApp = false;
  double _solasVgmPrice = 0.0;
  String _solasVgmCur = 'USD';

  bool _vgmNotifApp = false;
  double _vgmNotifPrice = 0.0;
  String _vgmNotifCur = 'USD';

  bool _telexReleaseApp = false;
  double _telexReleasePrice = 0.0;
  String _telexReleaseCur = 'USD';

  bool _insuranceApp = false;
  double _insurancePrice = 0.0;
  String _insuranceCur = 'USD';

  bool _cancellationApp = false;
  double _cancellationPrice = 0.0;
  String _cancellationCur = 'USD';

  bool _ics2App = false;
  double _ics2Price = 0.0;
  String _ics2Cur = 'USD';

  bool _otherFeesApp = false;
  double _otherFeesPrice = 0.0;
  String _otherFeesCur = 'USD';

  bool _docFeesApp = false;
  double _docFeesPrice = 0.0;
  String _docFeesCur = 'USD';

  bool _waiverApp = false;
  double _waiverPrice = 0.0;
  String _waiverCur = 'USD';

  bool _dthcApp = false;
  double _dthcPrice = 0.0;
  String _dthcCur = 'USD';

  bool _storagePerWeekApp = false;
  double _storagePerWeekPrice = 0.0;
  String _storagePerWeekCur = 'USD';

  bool _extraDayStorageApp = false;
  double _extraDayStoragePrice = 0.0;
  String _extraDayStorageCur = 'USD';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bookingToEdit;
    _bookingConfirmNoController = TextEditingController(text: b?.bookingConfirmationNo ?? 'MSC-CN-889001');
    _polController = TextEditingController(text: b?.polName ?? 'Shanghai Port (CNSHA)');
    _podController = TextEditingController(text: b?.podName ?? 'Alexandria Port (EGALY)');
    _vesselNameController = TextEditingController(text: b?.vesselName ?? 'MSC Oscar');
    _voyageNoController = TextEditingController(text: b?.voyageNumber ?? 'VY-2026-X8');
    _releaseOrderNoController = TextEditingController(text: b?.containerReleaseOrderNo ?? 'RO-MSC-9912');
    _freeDemurrageController = TextEditingController(text: (b?.freeDemurrageDays ?? 14).toString());
    _expectedWhDaysController = TextEditingController(text: (b?.expectedWarehouseDays ?? 7).toString());
    _ownerController = TextEditingController(text: b?.owner ?? 'Kamal');
    _notesController = TextEditingController(text: b?.notes ?? '');

    _selectedImportFileId = b?.importFileId;
    _selectedScenarioSessionId = b?.scenarioSessionId;
    _selectedScenarioItemId = b?.scenarioItemId;
    _selectedScenarioProviderName = b?.scenarioProviderName;
    _containerMismatchReason = b?.containerMismatchReason;

    _shipmentType = b?.shipmentType ?? 'Ocean FCL';
    _freightTerms = b?.freightTerms ?? 'Collect';
    _status = b?.status ?? 'Draft';
    _shippingLineName = b?.shippingLineName ?? 'Mediterranean Shipping Company (MSC)';
    _freightForwarderName = b?.freightForwarderName ?? 'El-Ahram Logistics';

    if (b?.etd != null) _etd = DateTime.tryParse(b!.etd!) ?? _etd;
    if (b?.eta != null) _eta = DateTime.tryParse(b!.eta!) ?? _eta;
    if (b?.atd != null) _atd = DateTime.tryParse(b!.atd!);

    if (b?.containersData != null && b!.containersData.isNotEmpty) {
      _containers = List.from(b.containersData);
    } else {
      _containers = [
        ContainerAllocationModel(
          containerType: '40HC',
          quantity: 1,
          containerNumbers: ['MSCU1234567'],
          sealNumbers: ['SL-99001'],
          vgmWeightKg: 24500,
        )
      ];
    }

    if (b?.costChargesData != null && b!.costChargesData.isNotEmpty) {
      _charges = List.from(b.costChargesData);
    }

    if (b?.quotationDetailsData != null && b!.quotationDetailsData.isNotEmpty) {
      _loadQuotationDataFromMap(b.quotationDetailsData);
    }
  }

  void _loadQuotationDataFromMap(Map<String, dynamic> q) {
    _mainQuoteCurrency = q['main_quote_currency'] ?? 'USD';
    _originalQuoteTotalUsd = (q['original_quote_total_usd'] as num?)?.toDouble() ?? widget.bookingToEdit?.originalFreightCostUsd;
    _originalContainer40ftPrice = (q['original_container_40ft_price'] as num?)?.toDouble();
    _originalContainer20ftPrice = (q['original_container_20ft_price'] as num?)?.toDouble();
    _originalLclCbmPrice = (q['original_lcl_cbm_price'] as num?)?.toDouble();
    _originalExpressCourierPrice = (q['original_express_courier_price'] as num?)?.toDouble();

    _container40ftApp = q['container_40ft_app'] ?? true;
    _container40ftPrice = (q['container_40ft_price'] as num?)?.toDouble() ?? 8500.0;
    _container40ftCur = q['container_40ft_cur'] ?? 'USD';
    _container40ftQty = q['container_40ft_qty'] ?? 1;

    _container20ftApp = q['container_20ft_app'] ?? false;
    _container20ftPrice = (q['container_20ft_price'] as num?)?.toDouble() ?? 0.0;
    _container20ftCur = q['container_20ft_cur'] ?? 'USD';
    _container20ftQty = q['container_20ft_qty'] ?? 0;

    _lclCbmApp = q['lcl_cbm_app'] ?? false;
    _lclCbmPrice = (q['lcl_cbm_price'] as num?)?.toDouble() ?? 0.0;
    _lclCbmCur = q['lcl_cbm_cur'] ?? 'USD';
    _lclCbmQty = (q['lcl_cbm_qty'] as num?)?.toDouble() ?? 0.0;

    _expressCourierApp = q['express_courier_app'] ?? false;
    _expressCourierPrice = (q['express_courier_price'] as num?)?.toDouble() ?? 0.0;
    _expressCourierCur = q['express_courier_cur'] ?? 'USD';

    _eurAtrApp = q['eur_atr_app'] ?? false;
    _eurAtrPrice = (q['eur_atr_price'] as num?)?.toDouble() ?? 0.0;
    _eurAtrCur = q['eur_atr_cur'] ?? 'USD';

    _solasVgmApp = q['solas_vgm_app'] ?? false;
    _solasVgmPrice = (q['solas_vgm_price'] as num?)?.toDouble() ?? 0.0;
    _solasVgmCur = q['solas_vgm_cur'] ?? 'USD';

    _vgmNotifApp = q['vgm_notif_app'] ?? false;
    _vgmNotifPrice = (q['vgm_notif_price'] as num?)?.toDouble() ?? 0.0;
    _vgmNotifCur = q['vgm_notif_cur'] ?? 'USD';

    _telexReleaseApp = q['telex_release_app'] ?? false;
    _telexReleasePrice = (q['telex_release_price'] as num?)?.toDouble() ?? 0.0;
    _telexReleaseCur = q['telex_release_cur'] ?? 'USD';

    _insuranceApp = q['insurance_app'] ?? false;
    _insurancePrice = (q['insurance_price'] as num?)?.toDouble() ?? 0.0;
    _insuranceCur = q['insurance_cur'] ?? 'USD';

    _cancellationApp = q['cancellation_app'] ?? false;
    _cancellationPrice = (q['cancellation_price'] as num?)?.toDouble() ?? 0.0;
    _cancellationCur = q['cancellation_cur'] ?? 'USD';

    _ics2App = q['ics2_app'] ?? false;
    _ics2Price = (q['ics2_price'] as num?)?.toDouble() ?? 0.0;
    _ics2Cur = q['ics2_cur'] ?? 'USD';

    _otherFeesApp = q['other_fees_app'] ?? false;
    _otherFeesPrice = (q['other_fees_price'] as num?)?.toDouble() ?? 0.0;
    _otherFeesCur = q['other_fees_cur'] ?? 'USD';

    _docFeesApp = q['doc_fees_app'] ?? false;
    _docFeesPrice = (q['doc_fees_price'] as num?)?.toDouble() ?? 0.0;
    _docFeesCur = q['doc_fees_cur'] ?? 'USD';

    _waiverApp = q['waiver_app'] ?? false;
    _waiverPrice = (q['waiver_price'] as num?)?.toDouble() ?? 0.0;
    _waiverCur = q['waiver_cur'] ?? 'USD';

    _dthcApp = q['dthc_app'] ?? false;
    _dthcPrice = (q['dthc_price'] as num?)?.toDouble() ?? 0.0;
    _dthcCur = q['dthc_cur'] ?? 'USD';

    _storagePerWeekApp = q['storage_per_week_app'] ?? false;
    _storagePerWeekPrice = (q['storage_per_week_price'] as num?)?.toDouble() ?? 0.0;
    _storagePerWeekCur = q['storage_per_week_cur'] ?? 'USD';

    _extraDayStorageApp = q['extra_day_storage_app'] ?? false;
    _extraDayStoragePrice = (q['extra_day_storage_price'] as num?)?.toDouble() ?? 0.0;
    _extraDayStorageCur = q['extra_day_storage_cur'] ?? 'USD';
  }

  Map<String, dynamic> _buildQuotationDataMap() {
    return {
      'main_quote_currency': _mainQuoteCurrency,
      'container_40ft_app': _container40ftApp,
      'container_40ft_price': _container40ftPrice,
      'container_40ft_cur': _container40ftCur,
      'container_40ft_qty': _container40ftQty,
      'container_20ft_app': _container20ftApp,
      'container_20ft_price': _container20ftPrice,
      'container_20ft_cur': _container20ftCur,
      'container_20ft_qty': _container20ftQty,
      'lcl_cbm_app': _lclCbmApp,
      'lcl_cbm_price': _lclCbmPrice,
      'lcl_cbm_cur': _lclCbmCur,
      'lcl_cbm_qty': _lclCbmQty,
      'express_courier_app': _expressCourierApp,
      'express_courier_price': _expressCourierPrice,
      'express_courier_cur': _expressCourierCur,
      'eur_atr_app': _eurAtrApp,
      'eur_atr_price': _eurAtrPrice,
      'eur_atr_cur': _eurAtrCur,
      'solas_vgm_app': _solasVgmApp,
      'solas_vgm_price': _solasVgmPrice,
      'solas_vgm_cur': _solasVgmCur,
      'vgm_notif_app': _vgmNotifApp,
      'vgm_notif_price': _vgmNotifPrice,
      'vgm_notif_cur': _vgmNotifCur,
      'telex_release_app': _telexReleaseApp,
      'telex_release_price': _telexReleasePrice,
      'telex_release_cur': _telexReleaseCur,
      'insurance_app': _insuranceApp,
      'insurance_price': _insurancePrice,
      'insurance_cur': _insuranceCur,
      'cancellation_app': _cancellationApp,
      'cancellation_price': _cancellationPrice,
      'cancellation_cur': _cancellationCur,
      'ics2_app': _ics2App,
      'ics2_price': _ics2Price,
      'ics2_cur': _ics2Cur,
      'other_fees_app': _otherFeesApp,
      'other_fees_price': _otherFeesPrice,
      'other_fees_cur': _otherFeesCur,
      'doc_fees_app': _docFeesApp,
      'doc_fees_price': _docFeesPrice,
      'doc_fees_cur': _docFeesCur,
      'waiver_app': _waiverApp,
      'waiver_price': _waiverPrice,
      'waiver_cur': _waiverCur,
      'dthc_app': _dthcApp,
      'dthc_price': _dthcPrice,
      'dthc_cur': _dthcCur,
      'storage_per_week_app': _storagePerWeekApp,
      'storage_per_week_price': _storagePerWeekPrice,
      'storage_per_week_cur': _storagePerWeekCur,
      'extra_day_storage_app': _extraDayStorageApp,
      'extra_day_storage_price': _extraDayStoragePrice,
      'extra_day_storage_cur': _extraDayStorageCur,
      if (_originalQuoteTotalUsd != null) 'original_quote_total_usd': _originalQuoteTotalUsd,
      if (_originalContainer40ftPrice != null) 'original_container_40ft_price': _originalContainer40ftPrice,
      if (_originalContainer20ftPrice != null) 'original_container_20ft_price': _originalContainer20ftPrice,
      if (_originalLclCbmPrice != null) 'original_lcl_cbm_price': _originalLclCbmPrice,
      if (_originalExpressCourierPrice != null) 'original_express_courier_price': _originalExpressCourierPrice,
    };
  }

  @override
  void dispose() {
    _bookingConfirmNoController.dispose();
    _polController.dispose();
    _podController.dispose();
    _vesselNameController.dispose();
    _voyageNoController.dispose();
    _releaseOrderNoController.dispose();
    _freeDemurrageController.dispose();
    _expectedWhDaysController.dispose();
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyScenarioQuote(ShippingEvaluationModel session, ShippingScenarioItemModel item) {
    setState(() {
      _selectedScenarioSessionId = session.sessionId;
      _selectedScenarioItemId = item.itemId;
      _selectedScenarioProviderName = item.providerName;

      _shippingLineName = item.providerName;
      _freightForwarderName = item.providerName;
      _vesselNameController.text = item.vesselName;
      if (item.voyageNumber != null && item.voyageNumber!.isNotEmpty) {
        _voyageNoController.text = item.voyageNumber!;
      }
      if (item.polName != null && item.polName!.isNotEmpty) {
        _polController.text = item.polName!;
      }
      if (item.podName != null && item.podName!.isNotEmpty) {
        _podController.text = item.podName!;
      }
      final parsedEtd = DateTime.tryParse(item.sailingDate);
      if (parsedEtd != null) _etd = parsedEtd;
      final parsedEta = DateTime.tryParse(item.estimatedArrivalDate);
      if (parsedEta != null) _eta = parsedEta;
      _freeDemurrageController.text = item.freeTimeDays.toString();
      _mainQuoteCurrency = item.quotationCurrency;
      _originalQuoteTotalUsd = item.totalQuotationAmount;
      _originalContainer40ftPrice = item.container40ftPrice;
      _originalContainer20ftPrice = item.container20ftPrice;
      _originalLclCbmPrice = item.lclCbmPrice;
      _originalExpressCourierPrice = item.expressCourierPrice;

      // Map all 17 quote breakdown parameters
      _container40ftApp = item.container40ftApplicable;
      _container40ftPrice = item.container40ftPrice;
      _container40ftCur = item.container40ftCurrency;
      _container40ftQty = item.container40ftQty > 0 ? item.container40ftQty : 1;

      _container20ftApp = item.container20ftApplicable;
      _container20ftPrice = item.container20ftPrice;
      _container20ftCur = item.container20ftCurrency;
      _container20ftQty = item.container20ftQty;

      _lclCbmApp = item.lclCbmApplicable;
      _lclCbmPrice = item.lclCbmPrice;
      _lclCbmCur = item.lclCbmCurrency;
      _lclCbmQty = item.lclCbmQty;

      _expressCourierApp = item.expressCourierApplicable;
      _expressCourierPrice = item.expressCourierPrice;
      _expressCourierCur = item.expressCourierCurrency;

      _eurAtrApp = item.eurAtrApplicable;
      _eurAtrPrice = item.eurAtrPrice;
      _eurAtrCur = item.eurAtrCurrency;

      _solasVgmApp = item.solasVgmApplicable;
      _solasVgmPrice = item.solasVgmPrice;
      _solasVgmCur = item.solasVgmCurrency;

      _vgmNotifApp = item.vgmNotificationApplicable;
      _vgmNotifPrice = item.vgmNotificationPrice;
      _vgmNotifCur = item.vgmNotificationCurrency;

      _telexReleaseApp = item.telexReleaseApplicable;
      _telexReleasePrice = item.telexReleasePrice;
      _telexReleaseCur = item.telexReleaseCurrency;

      _insuranceApp = item.insuranceApplicable;
      _insurancePrice = item.insurancePrice;
      _insuranceCur = item.insuranceCurrency;

      _cancellationApp = item.bookingCancellationApplicable;
      _cancellationPrice = item.bookingCancellationPrice;
      _cancellationCur = item.bookingCancellationCurrency;

      _ics2App = item.ics2FilingFeeApplicable;
      _ics2Price = item.ics2FilingFeePrice;
      _ics2Cur = item.ics2FilingFeeCurrency;

      _otherFeesApp = item.othersFeeApplicable;
      _otherFeesPrice = item.othersFeePrice;
      _otherFeesCur = item.othersFeeCurrency;

      _docFeesApp = item.documentFeesApplicable;
      _docFeesPrice = item.documentFeesPrice;
      _docFeesCur = item.documentFeesCurrency;

      _waiverApp = item.waiverLetterFeeApplicable;
      _waiverPrice = item.waiverLetterFeePrice;
      _waiverCur = item.waiverLetterFeeCurrency;

      _dthcApp = item.dthcApplicable;
      _dthcPrice = item.dthcPrice;
      _dthcCur = item.dthcCurrency;

      _storagePerWeekApp = item.storagePerWeekApplicable;
      _storagePerWeekPrice = item.storagePerWeekPrice;
      _storagePerWeekCur = item.storagePerWeekCurrency;

      _extraDayStorageApp = item.extraDayStorageApplicable;
      _extraDayStoragePrice = item.extraDayStoragePrice;
      _extraDayStorageCur = item.extraDayStorageCurrency;

      // Auto-assign containers based on quotation
      final List<ContainerAllocationModel> newContainers = [];
      if (item.container40ftApplicable && item.container40ftQty > 0) {
        newContainers.add(ContainerAllocationModel(
          containerType: '40HC',
          quantity: item.container40ftQty,
          containerNumbers: List.generate(item.container40ftQty, (i) => 'MSCU${1000000 + (i * 111111)}'),
          sealNumbers: List.generate(item.container40ftQty, (i) => 'SL-40HC-${i + 1}'),
          vgmWeightKg: 24500.0 * item.container40ftQty,
        ));
      }
      if (item.container20ftApplicable && item.container20ftQty > 0) {
        newContainers.add(ContainerAllocationModel(
          containerType: '20GP',
          quantity: item.container20ftQty,
          containerNumbers: List.generate(item.container20ftQty, (i) => 'MSCU${2000000 + (i * 111111)}'),
          sealNumbers: List.generate(item.container20ftQty, (i) => 'SL-20GP-${i + 1}'),
          vgmWeightKg: 14000.0 * item.container20ftQty,
        ));
      }
      if (newContainers.isNotEmpty) {
        _containers = newContainers;
        _shipmentType = 'Ocean FCL';
      } else if (item.lclCbmApplicable && item.lclCbmQty > 0) {
        _shipmentType = 'Ocean LCL';
      }

      // Rebuild charges list
      _rebuildChargesFromQuoteBreakdown();
    });

    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚢 ${l.freightBookingQuoteAppliedSuccess(item.providerName, item.vesselName)}'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _rebuildChargesFromQuoteBreakdown() {
    final List<BookingChargeModel> newCharges = [];
    if (_container40ftApp && _container40ftPrice > 0) {
      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 40ft',
        unit: 'Per Container',
        quantity: _container40ftQty > 0 ? _container40ftQty : 1,
        currency: _container40ftCur,
        rate: _container40ftPrice,
        total: _container40ftPrice * (_container40ftQty > 0 ? _container40ftQty : 1),
      ));
    }
    if (_container20ftApp && _container20ftPrice > 0) {
      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 20ft',
        unit: 'Per Container',
        quantity: _container20ftQty > 0 ? _container20ftQty : 1,
        currency: _container20ftCur,
        rate: _container20ftPrice,
        total: _container20ftPrice * (_container20ftQty > 0 ? _container20ftQty : 1),
      ));
    }
    if (_lclCbmApp && _lclCbmPrice > 0) {
      newCharges.add(BookingChargeModel(
        chargeType: 'LCL CBM Freight',
        unit: 'Per CBM',
        quantity: _lclCbmQty.ceil() > 0 ? _lclCbmQty.ceil() : 1,
        currency: _lclCbmCur,
        rate: _lclCbmPrice,
        total: _lclCbmPrice * _lclCbmQty,
      ));
    }
    if (_dthcApp && _dthcPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'DTHC (Destination THC)', unit: 'Per Shipment', quantity: 1, currency: _dthcCur, rate: _dthcPrice, total: _dthcPrice));
    }
    if (_storagePerWeekApp && _storagePerWeekPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Storage per one week', unit: 'Per Week', quantity: 1, currency: _storagePerWeekCur, rate: _storagePerWeekPrice, total: _storagePerWeekPrice));
    }
    if (_extraDayStorageApp && _extraDayStoragePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Extra day storage', unit: 'Per Day', quantity: 1, currency: _extraDayStorageCur, rate: _extraDayStoragePrice, total: _extraDayStoragePrice));
    }
    if (_solasVgmApp && _solasVgmPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'SOLAS/VGM Fees', unit: 'Per Container', quantity: 1, currency: _solasVgmCur, rate: _solasVgmPrice, total: _solasVgmPrice));
    }
    if (_vgmNotifApp && _vgmNotifPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'VGM Notification Fee', unit: 'Per Container', quantity: 1, currency: _vgmNotifCur, rate: _vgmNotifPrice, total: _vgmNotifPrice));
    }
    if (_telexReleaseApp && _telexReleasePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Telex Release', unit: 'Per Shipment', quantity: 1, currency: _telexReleaseCur, rate: _telexReleasePrice, total: _telexReleasePrice));
    }
    if (_expressCourierApp && _expressCourierPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Express Courier', unit: 'Per Shipment', quantity: 1, currency: _expressCourierCur, rate: _expressCourierPrice, total: _expressCourierPrice));
    }
    if (_eurAtrApp && _eurAtrPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'EUR.1 / ATR Certificate', unit: 'Per Certificate', quantity: 1, currency: _eurAtrCur, rate: _eurAtrPrice, total: _eurAtrPrice));
    }
    if (_insuranceApp && _insurancePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Marine Insurance', unit: 'Per Policy', quantity: 1, currency: _insuranceCur, rate: _insurancePrice, total: _insurancePrice));
    }
    if (_docFeesApp && _docFeesPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Document Fees', unit: 'Per Shipment', quantity: 1, currency: _docFeesCur, rate: _docFeesPrice, total: _docFeesPrice));
    }
    if (_waiverApp && _waiverPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Waiver Letter Fee', unit: 'Per Letter', quantity: 1, currency: _waiverCur, rate: _waiverPrice, total: _waiverPrice));
    }
    if (_ics2App && _ics2Price > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'ICS2 Filing Fee', unit: 'Per Filing', quantity: 1, currency: _ics2Cur, rate: _ics2Price, total: _ics2Price));
    }
    if (_otherFeesApp && _otherFeesPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Other Fees', unit: 'Per Shipment', quantity: 1, currency: _otherFeesCur, rate: _otherFeesPrice, total: _otherFeesPrice));
    }

    _charges = newCharges;
  }

  Future<void> _submitWithContainerValidation(ContainerRecommendationResult? rec) async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);

    // Check Container Matching
    if (rec != null) {
      int assignedTotal = _containers.fold(0, (sum, c) => sum + c.quantity);
      String assignedType = _containers.isNotEmpty ? _containers.first.containerType : 'N/A';
      String suggestedType = rec.recommendedContainerCode;
      int suggestedTotal = rec.requiredContainersCount;

      bool isMismatch = (assignedTotal != suggestedTotal) || (_containers.length == 1 && assignedType != suggestedType);

      if (isMismatch && (_containerMismatchReason == null || _containerMismatchReason!.trim().isEmpty)) {
        final assignedStr = '$assignedTotal x $assignedType';
        final suggestedStr = '$suggestedTotal x $suggestedType';

        final bool? shouldProceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Text(l.freightBookingMismatchTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ ${l.freightBookingMismatchWarning(assignedStr, suggestedStr)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Text(l.freightBookingMismatchPrompt, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    'ℹ️ ${l.freightBookingMismatchNote}',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.freightBookingMismatchBtnNo, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.freightBookingMismatchBtnYes, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          return;
        }

        if (!mounted) return;

        // Prompt user for mandatory reason
        final reasonController = TextEditingController();
        final formKeyReason = GlobalKey<FormState>();
        final bool? reasonConfirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(l.freightBookingMismatchReasonTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            content: Form(
              key: formKeyReason,
              child: TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l.freightBookingMismatchReasonHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l.freightBookingMismatchReasonValidator : null,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                onPressed: () {
                  if (formKeyReason.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text(l.freightBookingMismatchReasonConfirm, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (reasonConfirmed == true) {
          setState(() {
            _containerMismatchReason = reasonController.text.trim();
          });
        } else {
          return;
        }
      }
    }

    _doSave();
  }

  Future<void> _doSave() async {
    setState(() => _isSaving = true);
    final l = AppLocalizations.of(context);
    try {
      _rebuildChargesFromQuoteBreakdown();

      final payload = {
        'booking_confirmation_no': _bookingConfirmNoController.text.trim(),
        'import_file_id': _selectedImportFileId,
        'scenario_session_id': _selectedScenarioSessionId,
        'scenario_item_id': _selectedScenarioItemId,
        'scenario_provider_name': _selectedScenarioProviderName,
        'freight_forwarder_name': _freightForwarderName,
        'shipping_line_name': _shippingLineName,
        'shipment_type': _shipmentType,
        'pol_name': _polController.text.trim(),
        'pod_name': _podController.text.trim(),
        'etd': _etd.toIso8601String(),
        'eta': _eta.toIso8601String(),
        'atd': _atd?.toIso8601String(),
        'free_demurrage_days': int.tryParse(_freeDemurrageController.text.trim()) ?? 14,
        'expected_warehouse_days': int.tryParse(_expectedWhDaysController.text.trim()) ?? 7,
        'vessel_name': _vesselNameController.text.trim(),
        'voyage_number': _voyageNoController.text.trim(),
        'container_release_order_no': _releaseOrderNoController.text.trim(),
        'freight_terms': _freightTerms,
        'container_mismatch_reason': _containerMismatchReason,
        'containers_data': _containers.map((c) => c.toJson()).toList(),
        'cost_charges_data': _charges.map((c) => c.toJson()).toList(),
        'quotation_details_data': _buildQuotationDataMap(),
        'original_freight_cost_usd': _originalQuoteTotalUsd,
        'status': _status,
        'owner': _ownerController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      if (widget.bookingToEdit == null) {
        await ref.read(freightBookingProvider.notifier).createBooking(payload);
      } else {
        await ref.read(freightBookingProvider.notifier).updateBooking(widget.bookingToEdit!.bookingId, payload);
      }

      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(liveLogisticsTrackingProvider);
      ref.invalidate(importFilesProvider);
      ref.invalidate(smartTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${l.freightBookingSaveSuccess}'), backgroundColor: AppTheme.emerald),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('يوجد بالفعل حجز شحن') || errStr.contains('مسجل لهذا الملف')) {
          final existingBookings = ref.read(freightBookingProvider).valueOrNull ?? [];
          final duplicate = existingBookings.where((b) => b.importFileId == _selectedImportFileId && b.isActive).toList();
          if (duplicate.isNotEmpty) {
            _showDuplicateBookingWarningDialog(duplicate.first);
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDuplicateBookingWarningDialog(ShipmentBookingModel existing) {
    final l = AppLocalizations.of(context);
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final curFile = importFiles.where((f) => f.importFileId == existing.importFileId).toList();
    final fileLabel = curFile.isNotEmpty
        ? '${curFile.first.primaryNameWithCode} (${curFile.first.companyName})'
        : 'IMP-${existing.importFileId}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.freightBookingDuplicateTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              ),
            ),
          ],
        ),
        content: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 500.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.freightBookingDuplicateMessage,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900),
              ),
              const SizedBox(height: 10),
              _buildDuplicateInfoRow(l.freightBookingDuplicateRowFile, fileLabel),
              _buildDuplicateInfoRow(l.freightBookingDuplicateRowCode, existing.bookingCode),
              _buildDuplicateInfoRow(l.freightBookingDuplicateRowConfirmNo, existing.bookingConfirmationNo ?? 'Draft Pending'),
              _buildDuplicateInfoRow(l.freightBookingDuplicateRowLine, existing.shippingLineName ?? 'N/A'),
              _buildDuplicateInfoRow(l.freightBookingDuplicateRowStatus, existing.status),
              _buildDuplicateInfoRow('المستخدم المسؤول', existing.owner),
              _buildDuplicateInfoRow('آخر تحديث', existing.updatedAt),
              const Divider(height: 20),
              Text(
                l.freightBookingDuplicateNotice,
                style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedImportFileId = null;
              });
            },
            child: Text(l.freightBookingDuplicateBtnCancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(l.freightBookingDuplicateBtnSwitch, style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              // Capture overlay entry (root navigator) before any pop
              final rootNav = Navigator.of(ctx, rootNavigator: false);
              rootNav.pop(); // Close warning dialog
              rootNav.pop(); // Close current form dialog
              // Open edit dialog for existing booking in next frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!rootNav.context.mounted) return;
                showDialog(
                  context: rootNav.context,
                  barrierDismissible: false,
                  builder: (c) => _FreightBookingFormDialog(bookingToEdit: existing),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  double get _computedCurrentExecutedFreight {
    double total = 0.0;
    if (_container40ftApp) total += _container40ftPrice * (_container40ftQty > 0 ? _container40ftQty : 1);
    if (_container20ftApp) total += _container20ftPrice * (_container20ftQty > 0 ? _container20ftQty : 1);
    if (_lclCbmApp) total += _lclCbmPrice * _lclCbmQty;
    if (_expressCourierApp) total += _expressCourierPrice;
    if (_eurAtrApp) total += _eurAtrPrice;
    if (_solasVgmApp) total += _solasVgmPrice;
    if (_vgmNotifApp) total += _vgmNotifPrice;
    if (_telexReleaseApp) total += _telexReleasePrice;
    if (_insuranceApp) total += _insurancePrice;
    if (_cancellationApp) total += _cancellationPrice;
    if (_ics2App) total += _ics2Price;
    if (_otherFeesApp) total += _otherFeesPrice;
    if (_docFeesApp) total += _docFeesPrice;
    if (_waiverApp) total += _waiverPrice;
    if (_dthcApp) total += _dthcPrice;
    if (_storagePerWeekApp) total += _storagePerWeekPrice;
    if (_extraDayStorageApp) total += _extraDayStoragePrice;
    return total;
  }

  Widget _buildLiveSavingsFormBanner(AppLocalizations l) {
    if (_originalQuoteTotalUsd == null || _originalQuoteTotalUsd! <= 0) {
      return const SizedBox.shrink();
    }
    final orig = _originalQuoteTotalUsd!;
    final exec = _computedCurrentExecutedFreight;
    final diff = (orig - exec).abs();
    final hasSavings = exec < orig;
    final hasIncrease = exec > orig;
    final pct = orig > 0 ? (diff / orig * 100) : 0.0;

    final primaryColor = hasSavings
        ? AppTheme.emerald
        : (hasIncrease ? AppTheme.crimson : AppTheme.cobalt);
    final bgColor = hasSavings
        ? const Color(0xFFF0FDF4)
        : (hasIncrease ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC));
    final borderColor = hasSavings
        ? Colors.green.shade300
        : (hasIncrease ? Colors.red.shade300 : Colors.blueGrey.shade200);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSavings
                    ? Icons.savings_outlined
                    : (hasIncrease ? Icons.trending_up : Icons.compare_arrows),
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasSavings
                      ? '🎉 ${l.freightBookingCostSavingsTitle}'
                      : (hasIncrease
                          ? '⚠️ ${l.freightBookingCostIncreaseTitle}'
                          : l.freightBookingNoPriceVariance),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  hasSavings
                      ? 'توفير: \$${diff.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)'
                      : (hasIncrease ? 'زيادة: \$${diff.toStringAsFixed(2)}' : 'مطابق'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• ${l.freightBookingOriginalQuotedPrice}: \$${orig.toStringAsFixed(2)}  ➔  ${l.freightBookingExecutedPrice}: \$${exec.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
          ),
        ],
      ),
    );
  }

  Widget _buildCostItemRow({
    required BuildContext context,
    required String title,
    required bool isApplicable,
    required ValueChanged<bool> onToggle,
    required double price,
    required ValueChanged<double> onPriceChanged,
    required String currency,
    required ValueChanged<String> onCurrencyChanged,
    int? quantity,
    ValueChanged<int>? onQuantityChanged,
    double? doubleQty,
    ValueChanged<double>? onDoubleQtyChanged,
  }) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isApplicable ? AppTheme.emerald.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isApplicable ? AppTheme.emerald.withOpacity(0.3) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(title, style: TextStyle(fontWeight: isApplicable ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: price > 0 ? price.toStringAsFixed(0) : '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.freightBookingItemRateLabel, isDense: true, border: const OutlineInputBorder()),
              onChanged: (v) => onPriceChanged(double.tryParse(v) ?? 0.0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: SearchableDropdownField<String>(
              value: currency,
              labelText: l.freightBookingCurrencyLabel,
              searchHintText: 'USD, EUR...',
              items: const [
                SearchableDropdownItem(value: 'USD', label: 'USD (\$)'),
                SearchableDropdownItem(value: 'EUR', label: 'EUR (€)'),
                SearchableDropdownItem(value: 'EGP', label: 'EGP (ج.م)'),
                SearchableDropdownItem(value: 'GBP', label: 'GBP (£)'),
                SearchableDropdownItem(value: 'CNY', label: 'CNY (¥)'),
              ],
              onChanged: (v) {
                if (v != null) onCurrencyChanged(v);
              },
            ),
          ),
          if (quantity != null && onQuantityChanged != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: quantity.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.freightBookingQuantityLabel, isDense: true, border: const OutlineInputBorder()),
                onChanged: (v) => onQuantityChanged(int.tryParse(v) ?? 1),
              ),
            ),
          ],
          if (doubleQty != null && onDoubleQtyChanged != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: doubleQty.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.freightBookingCbmVolumeLabel, isDense: true, border: const OutlineInputBorder()),
                onChanged: (v) => onDoubleQtyChanged(double.tryParse(v) ?? 0.0),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Switch(
            value: isApplicable,
            activeColor: AppTheme.emerald,
            onChanged: (v) {
              onToggle(v);
              _rebuildChargesFromQuoteBreakdown();
            },
          ),
          SizedBox(
            width: 70,
            child: Text(
              isApplicable ? l.freightBookingItemActive : l.freightBookingItemInactive,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isApplicable ? AppTheme.emerald : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final partners = ref.watch(allPartnersProvider).valueOrNull ?? ref.watch(partnersProvider).valueOrNull ?? [];
    final ports = ref.watch(transportLocationsProvider).valueOrNull ?? [];
    final shippingSessions = ref.watch(shippingScenariosProvider).sessions;
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;

    final shippingLines = partners.where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Carrier') || p.partnerType.contains('Bank') || p.partnerType.contains('Freight')).toList();
    final freightForwarders = partners.where((p) => p.partnerType.contains('Forwarder') || p.partnerType.contains('Logistics') || p.partnerType.contains('Freight')).toList();

    // Quotes for selected file
    final matchingSessions = _selectedImportFileId != null
        ? shippingSessions.where((s) => s.importFileId == _selectedImportFileId).toList()
        : <ShippingEvaluationModel>[];

    // Compute Cargo Stacking from Packing Lists
    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    if (_selectedImportFileId != null && importFiles.any((f) => f.importFileId == _selectedImportFileId)) {
      final curFile = importFiles.firstWhere((f) => f.importFileId == _selectedImportFileId);
      for (var pl in curFile.packingListsData) {
        totalCargoCbm += pl.cbm;
        totalCargoWeightKg += pl.grossWeightKg;
      }
      final filePos = poList.where((p) => (curFile.poIds ?? []).contains(p.poId)).toList();
      for (var po in filePos) {
        for (var pl in po.packingListItems) {
          totalCargoCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
          totalCargoWeightKg += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
        }
      }
    }

    if (totalCargoCbm == 0 && _selectedImportFileId != null) {
      totalCargoCbm = 40.0;
      totalCargoWeightKg = 2274.0;
    }

    final containerDualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: totalCargoCbm > 0 ? totalCargoCbm : 40.0,
      totalWeightKg: totalCargoWeightKg > 0 ? totalCargoWeightKg : 2274.0,
    );
    final activeContainerRec = _isStackable ? containerDualRec.stackableResult : containerDualRec.nonStackableResult;

    // Delay calculation
    final int delayDays = _atd != null ? _atd!.difference(_etd).inDays : 0;
    final int whDays = int.tryParse(_expectedWhDaysController.text.trim()) ?? 7;
    final DateTime computedWhArrival = _eta.add(Duration(days: (delayDays > 0 ? delayDays : 0) + whDays));

    final l = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_boat, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Text(
                  widget.bookingToEdit == null ? l.freightBookingNewDialogTitle : l.freightBookingEditDialogTitle(widget.bookingToEdit!.bookingCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.bookingToEdit != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 15),
                    label: const Text('سجل التدقيق', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      RowHistoryDialog.show(
                        context,
                        entityType: 'ShipmentBooking',
                        entityId: widget.bookingToEdit!.bookingId,
                        entityTitle: 'حجز الشحن ${widget.bookingToEdit!.bookingCode}',
                      );
                    },
                  ),
                ],
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: l.freightBookingCloseTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 960.0),
          height: 680,
          child: Column(
            children: [
              TabBar(
                labelColor: AppTheme.cobalt,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.cobalt,
                tabs: [
                  Tab(icon: const Icon(Icons.description), text: l.freightBookingTabBookingDetails),
                  Tab(icon: const Icon(Icons.attach_money), text: l.freightBookingTabCostBreakdown),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    children: [
                      // ================= TAB 1: BOOKING DETAILS & ROUTE =================
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SearchableDropdownField<int?>(
                                    value: _selectedImportFileId,
                                    labelText: l.freightBookingImportFileLabel,
                                    searchHintText: l.freightBookingImportFileHint,
                                    items: importFiles
                                        .map((f) => SearchableDropdownItem<int?>(
                                              value: f.importFileId,
                                              label: '${f.primaryNameWithCode} (${f.companyName})',
                                              subtitle: f.supplierName,
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val == null) {
                                        setState(() => _selectedImportFileId = null);
                                        return;
                                      }
                                      // Check if there is already an active booking for this file
                                      final existingBookings = ref.read(freightBookingProvider).valueOrNull ?? [];
                                      final duplicate = existingBookings.where((b) =>
                                          b.importFileId == val &&
                                          b.isActive &&
                                          (widget.bookingToEdit == null || b.bookingId != widget.bookingToEdit!.bookingId)
                                      ).toList();

                                      if (duplicate.isNotEmpty) {
                                        _showDuplicateBookingWarningDialog(duplicate.first);
                                        return;
                                      }

                                      setState(() {
                                        _selectedImportFileId = val;
                                        // If there are evaluated quotes, auto-select recommended
                                        final matched = shippingSessions.where((s) => s.importFileId == val).toList();
                                        if (matched.isNotEmpty && matched.first.items.isNotEmpty) {
                                          final rec = matched.first.items.firstWhere((i) => i.isRecommended, orElse: () => matched.first.items.first);
                                          _applyScenarioQuote(matched.first, rec);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _bookingConfirmNoController,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(labelText: l.freightBookingConfirmNoInputLabel, border: const OutlineInputBorder()),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? l.freightBookingConfirmNoValidator : null,
                                  ),
                                ),
                              ],
                            ),

                            // Evaluated Shipping Scenarios & Quotes Link Section
                            if (_selectedImportFileId != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_shipping, color: AppTheme.cobalt, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          l.freightBookingEvaluatedQuotesHeader,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                        ),
                                        const Spacer(),
                                        if (matchingSessions.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: AppTheme.cobalt.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                            child: Text(
                                              l.freightBookingAvailableQuotesBadge(matchingSessions.fold<int>(0, (sum, s) => sum + s.items.length)),
                                              style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (matchingSessions.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          l.freightBookingNoEvaluatedQuotes,
                                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        l.freightBookingApplyQuoteInstruction,
                                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 8),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: matchingSessions.fold<List<Map<String, dynamic>>>(
                                          [],
                                          (list, s) {
                                            for (var item in s.items) {
                                              list.add({'session': s, 'item': item});
                                            }
                                            return list;
                                          },
                                        ).length,
                                        separatorBuilder: (c, i) => const SizedBox(height: 8),
                                        itemBuilder: (context, idx) {
                                          final allItems = matchingSessions.fold<List<Map<String, dynamic>>>(
                                            [],
                                            (list, s) {
                                              for (var item in s.items) {
                                                list.add({'session': s, 'item': item});
                                              }
                                              return list;
                                            },
                                          );
                                          final pair = allItems[idx];
                                          final ShippingEvaluationModel sess = pair['session'];
                                          final ShippingScenarioItemModel item = pair['item'];
                                          final bool isSelected = _selectedScenarioItemId == item.itemId ||
                                              (_selectedScenarioProviderName == item.providerName && _vesselNameController.text == item.vesselName);

                                          return Card(
                                            elevation: isSelected ? 3 : 1,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: isSelected ? AppTheme.emerald : Colors.grey.shade300,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            color: isSelected ? AppTheme.emerald.withOpacity(0.06) : Colors.white,
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  // Carrier & Vessel Details
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              item.providerName,
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                                            ),
                                                            if (item.isRecommended) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.amber.shade100,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: Colors.amber.shade400),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(Icons.star, color: Colors.amber, size: 12),
                                                                    const SizedBox(width: 2),
                                                                    Text(l.freightBookingBestQuoteBadge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '🚢 ${l.freightBookingQuoteVesselDetails(item.vesselName, item.voyageNumber ?? "-", item.polName ?? "-", item.podName ?? "-")}',
                                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '📅 ${l.freightBookingQuoteScheduleDetails(item.sailingDate, item.estimatedArrivalDate, item.freeTimeDays)}',
                                                          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Price & Containers Info
                                                  Expanded(
                                                    flex: 2,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          '${item.totalQuotationAmount.toStringAsFixed(0)} ${item.quotationCurrency}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.emerald),
                                                        ),
                                                        Text(
                                                          l.freightBookingQuoteStudyRef(sess.sessionCode, sess.cargoReadyDate),
                                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // Select / Active Action
                                                  if (isSelected)
                                                    ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppTheme.emerald,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      ),
                                                      onPressed: () => _applyScenarioQuote(sess, item),
                                                      icon: const Icon(Icons.check_circle, size: 16),
                                                      label: Text(l.freightBookingSelectedQuoteBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                    )
                                                  else
                                                    OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: AppTheme.cobalt,
                                                        side: const BorderSide(color: AppTheme.cobalt),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      ),
                                                      onPressed: () => _applyScenarioQuote(sess, item),
                                                      icon: const Icon(Icons.check, size: 16),
                                                      label: Text(l.freightBookingApplyQuoteBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: shippingLines.any((s) => s.partnerName == _shippingLineName) ? _shippingLineName : (shippingLines.isNotEmpty ? shippingLines.first.partnerName : _shippingLineName),
                                    labelText: l.freightBookingShippingLineLabel,
                                    searchHintText: l.freightBookingShippingLineHint,
                                    items: shippingLines.isNotEmpty
                                        ? shippingLines.map((s) => SearchableDropdownItem<String>(value: s.partnerName, label: s.partnerName, subtitle: s.partnerType)).toList()
                                        : [SearchableDropdownItem<String>(value: _shippingLineName, label: _shippingLineName)],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _shippingLineName = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: freightForwarders.any((f) => f.partnerName == _freightForwarderName) ? _freightForwarderName : (freightForwarders.isNotEmpty ? freightForwarders.first.partnerName : _freightForwarderName),
                                    labelText: l.freightBookingForwarderLabel,
                                    searchHintText: l.freightBookingForwarderHint,
                                    items: freightForwarders.isNotEmpty
                                        ? freightForwarders.map((f) => SearchableDropdownItem<String>(value: f.partnerName, label: f.partnerName, subtitle: f.partnerType)).toList()
                                        : [SearchableDropdownItem<String>(value: _freightForwarderName, label: _freightForwarderName)],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _freightForwarderName = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: ports.any((p) => p.locationName == _polController.text) ? _polController.text : (ports.isNotEmpty ? ports.first.locationName : _polController.text),
                                    labelText: l.freightBookingPolLabel,
                                    searchHintText: l.freightBookingPolHint,
                                    items: ports.isNotEmpty
                                        ? ports.map((p) => SearchableDropdownItem<String>(value: p.locationName, label: p.locationName, subtitle: p.locationType)).toList()
                                        : [SearchableDropdownItem<String>(value: _polController.text, label: _polController.text)],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _polController.text = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: ports.any((p) => p.locationName == _podController.text) ? _podController.text : (ports.length > 1 ? ports[1].locationName : _podController.text),
                                    labelText: l.freightBookingPodLabel,
                                    searchHintText: l.freightBookingPodHint,
                                    items: ports.isNotEmpty
                                        ? ports.map((p) => SearchableDropdownItem<String>(value: p.locationName, label: p.locationName, subtitle: p.locationType)).toList()
                                        : [SearchableDropdownItem<String>(value: _podController.text, label: _podController.text)],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _podController.text = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Dates: ETD, ETA, ATD & Delay Tracking
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(context: context, initialDate: _etd, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                      if (d != null) setState(() => _etd = d);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: l.freightBookingEtdLabel, border: const OutlineInputBorder()),
                                      child: Text(_etd.toString().substring(0, 10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(context: context, initialDate: _eta, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                      if (d != null) setState(() => _eta = d);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: l.freightBookingEtaLabel, border: const OutlineInputBorder()),
                                      child: Text(_eta.toString().substring(0, 10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(context: context, initialDate: _atd ?? _etd, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                      if (d != null) setState(() => _atd = d);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: l.freightBookingAtdLabel,
                                        border: const OutlineInputBorder(),
                                        suffixIcon: _atd != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 16),
                                                onPressed: () => setState(() => _atd = null),
                                              )
                                            : null,
                                      ),
                                      child: Text(_atd != null ? _atd!.toString().substring(0, 10) : l.freightBookingPendingDate),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Departure Delay & Warehouse Lead Time Banner
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: delayDays > 0 ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: delayDays > 0 ? Colors.red.shade200 : Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(delayDays > 0 ? Icons.alarm_off : Icons.check_circle, color: delayDays > 0 ? Colors.red : Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    delayDays > 0 ? l.freightBookingDelayBannerDelayed(delayDays) : l.freightBookingDelayBannerOnTime,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: delayDays > 0 ? Colors.red.shade900 : Colors.green.shade900),
                                  ),
                                  const Spacer(),
                                  Text(
                                    l.freightBookingExpectedWhArrival(computedWhArrival.toString().substring(0, 10)),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _freeDemurrageController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: l.freightBookingFreeDaysInput, border: const OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _expectedWhDaysController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: l.freightBookingWarehouseDaysInput, border: const OutlineInputBorder()),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: _status,
                                    labelText: l.freightBookingStatusInputLabel,
                                    searchHintText: l.freightBookingFilterStatusHint,
                                    items: [
                                      SearchableDropdownItem(value: 'Draft', label: l.freightBookingStatusDraft),
                                      SearchableDropdownItem(value: 'Booking Requested', label: l.freightBookingStatusRequested),
                                      SearchableDropdownItem(value: 'Confirmed', label: l.freightBookingStatusConfirmed),
                                      SearchableDropdownItem(value: 'Sailed', label: l.freightBookingStatusSailed),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _status = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _vesselNameController,
                                    decoration: InputDecoration(labelText: l.freightBookingVesselNameInput, border: const OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _voyageNoController,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(labelText: l.freightBookingVoyageNoInput, border: const OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _releaseOrderNoController,
                                    decoration: InputDecoration(labelText: l.freightBookingReleaseOrderInput, border: const OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Booking Equipment Specification
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SearchableDropdownField<String>(
                                    value: _containers.isNotEmpty ? _containers.first.containerType : '40HC',
                                    labelText: l.freightBookingContainerTypeInput,
                                    searchHintText: '20GP, 40HC...',
                                    items: const [
                                      SearchableDropdownItem(value: '20GP', label: '20GP Standard'),
                                      SearchableDropdownItem(value: '40GP', label: '40GP Standard'),
                                      SearchableDropdownItem(value: '40HC', label: '40HC High Cube'),
                                      SearchableDropdownItem(value: '45HC', label: '45HC High Cube'),
                                      SearchableDropdownItem(value: '20RF', label: '20RF Reefer'),
                                      SearchableDropdownItem(value: '40RF', label: '40RF Reefer'),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          if (_containers.isEmpty) {
                                            _containers.add(ContainerAllocationModel(containerType: val, quantity: 1));
                                          } else {
                                            _containers[0] = ContainerAllocationModel(
                                              containerType: val,
                                              quantity: _containers[0].quantity,
                                              individualContainers: _containers[0].individualContainers,
                                              vgmWeightKg: _containers[0].vgmWeightKg,
                                            );
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: _containers.isNotEmpty ? _containers.first.quantity.toString() : '1',
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: l.freightBookingContainersQtyInput, border: const OutlineInputBorder()),
                                    onChanged: (val) {
                                      final q = int.tryParse(val) ?? 1;
                                      setState(() {
                                        if (_containers.isEmpty) {
                                          _containers.add(ContainerAllocationModel(containerType: '40HC', quantity: q));
                                        } else {
                                          _containers[0] = ContainerAllocationModel(
                                            containerType: _containers[0].containerType,
                                            quantity: q,
                                            individualContainers: _containers[0].individualContainers,
                                            vgmWeightKg: _containers[0].vgmWeightKg,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueGrey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: AppTheme.cobalt),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l.freightBookingEquipmentNote,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ================= TAB 2: COMPLETE 17 FREIGHT QUOTE DETAILS =================
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(l.freightBookingCostBreakdownTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
                                const Spacer(),
                                Text(l.freightBookingBaseCurrencyLabel(_mainQuoteCurrency), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildLiveSavingsFormBanner(l),

                            // 1. Container 40ft
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItem40ft,
                              isApplicable: _container40ftApp,
                              onToggle: (v) => setState(() => _container40ftApp = v),
                              price: _container40ftPrice,
                              onPriceChanged: (v) => setState(() => _container40ftPrice = v),
                              currency: _container40ftCur,
                              onCurrencyChanged: (v) => setState(() => _container40ftCur = v),
                              quantity: _container40ftQty,
                              onQuantityChanged: (v) => setState(() => _container40ftQty = v),
                            ),

                            // 2. Container 20ft
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItem20ft,
                              isApplicable: _container20ftApp,
                              onToggle: (v) => setState(() => _container20ftApp = v),
                              price: _container20ftPrice,
                              onPriceChanged: (v) => setState(() => _container20ftPrice = v),
                              currency: _container20ftCur,
                              onCurrencyChanged: (v) => setState(() => _container20ftCur = v),
                              quantity: _container20ftQty,
                              onQuantityChanged: (v) => setState(() => _container20ftQty = v),
                            ),

                            // 3. LCL CBM Cost
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemLcl,
                              isApplicable: _lclCbmApp,
                              onToggle: (v) => setState(() => _lclCbmApp = v),
                              price: _lclCbmPrice,
                              onPriceChanged: (v) => setState(() => _lclCbmPrice = v),
                              currency: _lclCbmCur,
                              onCurrencyChanged: (v) => setState(() => _lclCbmCur = v),
                              doubleQty: _lclCbmQty,
                              onDoubleQtyChanged: (v) => setState(() => _lclCbmQty = v),
                            ),

                            // 4. Express Courier
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemCourier,
                              isApplicable: _expressCourierApp,
                              onToggle: (v) => setState(() => _expressCourierApp = v),
                              price: _expressCourierPrice,
                              onPriceChanged: (v) => setState(() => _expressCourierPrice = v),
                              currency: _expressCourierCur,
                              onCurrencyChanged: (v) => setState(() => _expressCourierCur = v),
                            ),

                            // 5. EUR.1 / ATR Certificate
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemEur1,
                              isApplicable: _eurAtrApp,
                              onToggle: (v) => setState(() => _eurAtrApp = v),
                              price: _eurAtrPrice,
                              onPriceChanged: (v) => setState(() => _eurAtrPrice = v),
                              currency: _eurAtrCur,
                              onCurrencyChanged: (v) => setState(() => _eurAtrCur = v),
                            ),

                            // 6. SOLAS/VGM Fees
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemVgm,
                              isApplicable: _solasVgmApp,
                              onToggle: (v) => setState(() => _solasVgmApp = v),
                              price: _solasVgmPrice,
                              onPriceChanged: (v) => setState(() => _solasVgmPrice = v),
                              currency: _solasVgmCur,
                              onCurrencyChanged: (v) => setState(() => _solasVgmCur = v),
                            ),

                            // 7. VGM Notification Fee
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemVgmNotif,
                              isApplicable: _vgmNotifApp,
                              onToggle: (v) => setState(() => _vgmNotifApp = v),
                              price: _vgmNotifPrice,
                              onPriceChanged: (v) => setState(() => _vgmNotifPrice = v),
                              currency: _vgmNotifCur,
                              onCurrencyChanged: (v) => setState(() => _vgmNotifCur = v),
                            ),

                            // 8. Telex Release
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemTelex,
                              isApplicable: _telexReleaseApp,
                              onToggle: (v) => setState(() => _telexReleaseApp = v),
                              price: _telexReleasePrice,
                              onPriceChanged: (v) => setState(() => _telexReleasePrice = v),
                              currency: _telexReleaseCur,
                              onCurrencyChanged: (v) => setState(() => _telexReleaseCur = v),
                            ),

                            // 9. Marine Insurance
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemInsurance,
                              isApplicable: _insuranceApp,
                              onToggle: (v) => setState(() => _insuranceApp = v),
                              price: _insurancePrice,
                              onPriceChanged: (v) => setState(() => _insurancePrice = v),
                              currency: _insuranceCur,
                              onCurrencyChanged: (v) => setState(() => _insuranceCur = v),
                            ),

                            // 10. Booking Cancellation
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemCancellation,
                              isApplicable: _cancellationApp,
                              onToggle: (v) => setState(() => _cancellationApp = v),
                              price: _cancellationPrice,
                              onPriceChanged: (v) => setState(() => _cancellationPrice = v),
                              currency: _cancellationCur,
                              onCurrencyChanged: (v) => setState(() => _cancellationCur = v),
                            ),

                            // 11. ICS2 Filing Fee
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemIcs2,
                              isApplicable: _ics2App,
                              onToggle: (v) => setState(() => _ics2App = v),
                              price: _ics2Price,
                              onPriceChanged: (v) => setState(() => _ics2Price = v),
                              currency: _ics2Cur,
                              onCurrencyChanged: (v) => setState(() => _ics2Cur = v),
                            ),

                            // 12. Other Fees
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemOther,
                              isApplicable: _otherFeesApp,
                              onToggle: (v) => setState(() => _otherFeesApp = v),
                              price: _otherFeesPrice,
                              onPriceChanged: (v) => setState(() => _otherFeesPrice = v),
                              currency: _otherFeesCur,
                              onCurrencyChanged: (v) => setState(() => _otherFeesCur = v),
                            ),

                            // 13. Document Fees
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemDocFees,
                              isApplicable: _docFeesApp,
                              onToggle: (v) => setState(() => _docFeesApp = v),
                              price: _docFeesPrice,
                              onPriceChanged: (v) => setState(() => _docFeesPrice = v),
                              currency: _docFeesCur,
                              onCurrencyChanged: (v) => setState(() => _docFeesCur = v),
                            ),

                            // 14. Waiver Letter Fee
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemWaiver,
                              isApplicable: _waiverApp,
                              onToggle: (v) => setState(() => _waiverApp = v),
                              price: _waiverPrice,
                              onPriceChanged: (v) => setState(() => _waiverPrice = v),
                              currency: _waiverCur,
                              onCurrencyChanged: (v) => setState(() => _waiverCur = v),
                            ),

                            // 15. DTHC
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemDthc,
                              isApplicable: _dthcApp,
                              onToggle: (v) => setState(() => _dthcApp = v),
                              price: _dthcPrice,
                              onPriceChanged: (v) => setState(() => _dthcPrice = v),
                              currency: _dthcCur,
                              onCurrencyChanged: (v) => setState(() => _dthcCur = v),
                            ),

                            // 16. Storage per one week
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemStorageWeek,
                              isApplicable: _storagePerWeekApp,
                              onToggle: (v) => setState(() => _storagePerWeekApp = v),
                              price: _storagePerWeekPrice,
                              onPriceChanged: (v) => setState(() => _storagePerWeekPrice = v),
                              currency: _storagePerWeekCur,
                              onCurrencyChanged: (v) => setState(() => _storagePerWeekCur = v),
                            ),

                            // 17. Extra day storage
                            _buildCostItemRow(
                              context: context,
                              title: l.freightBookingItemStorageExtra,
                              isApplicable: _extraDayStorageApp,
                              onToggle: (v) => setState(() => _extraDayStorageApp = v),
                              price: _extraDayStoragePrice,
                              onPriceChanged: (v) => setState(() => _extraDayStoragePrice = v),
                              currency: _extraDayStorageCur,
                              onCurrencyChanged: (v) => setState(() => _extraDayStorageCur = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              side: BorderSide(color: Colors.red.shade300),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
            label: Text(l.freightBookingBtnCloseDiscard, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.charcoal,
              side: BorderSide(color: Colors.grey.shade400),
            ),
            onPressed: () {
              ref.read(freightBookingProvider.notifier).fetchBookings();
              ref.read(importFilesProvider.notifier).fetchImportFiles();
            },
            icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cobalt),
            label: Text(l.freightBookingBtnLiveReload, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade400),
            ),
            onPressed: () {
              setState(() {
                _selectedImportFileId = null;
                _selectedScenarioSessionId = null;
                _selectedScenarioItemId = null;
                _selectedScenarioProviderName = null;
                _bookingConfirmNoController.clear();
                _vesselNameController.clear();
                _voyageNoController.clear();
              });
            },
            icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Colors.blueGrey),
            label: Text(l.freightBookingBtnClearNew, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: AppTheme.cobalt,
              elevation: 0,
              side: const BorderSide(color: AppTheme.cobalt),
            ),
            onPressed: _isSaving ? null : () => _submitWithContainerValidation(activeContainerRec),
            icon: const Icon(Icons.save_outlined, size: 16, color: AppTheme.cobalt),
            label: Text(l.freightBookingBtnSaveDraft, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            onPressed: _isSaving ? null : () => _submitWithContainerValidation(activeContainerRec),
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(widget.bookingToEdit != null ? l.freightBookingBtnUpdate : l.freightBookingBtnSaveConfirm, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ================= CONFIRM BOOKING DIALOG (BK-01) =================
class _FreightBookingConfirmDialog extends ConsumerStatefulWidget {
  final ShipmentBookingModel booking;
  const _FreightBookingConfirmDialog({required this.booking});

  @override
  ConsumerState<_FreightBookingConfirmDialog> createState() => _FreightBookingConfirmDialogState();
}

class _FreightBookingConfirmDialogState extends ConsumerState<_FreightBookingConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bookingNoController;
  late final TextEditingController _vesselNameController;
  late final TextEditingController _voyageNumberController;
  late final TextEditingController _freeDaysController;
  late final TextEditingController _notesController;

  DateTime? _selectedEtd;
  DateTime? _selectedEta;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bookingNoController = TextEditingController(text: widget.booking.bookingConfirmationNo ?? '');
    _vesselNameController = TextEditingController(text: widget.booking.vesselName ?? '');
    _voyageNumberController = TextEditingController(text: widget.booking.voyageNumber ?? '');
    _freeDaysController = TextEditingController(text: widget.booking.freeDemurrageDays.toString());
    _notesController = TextEditingController(text: widget.booking.notes ?? '');

    if (widget.booking.etd != null) {
      _selectedEtd = DateTime.tryParse(widget.booking.etd!);
    }
    if (widget.booking.eta != null) {
      _selectedEta = DateTime.tryParse(widget.booking.eta!);
    }
  }

  @override
  void dispose() {
    _bookingNoController.dispose();
    _vesselNameController.dispose();
    _voyageNumberController.dispose();
    _freeDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isEtd) async {
    final initial = isEtd ? (_selectedEtd ?? DateTime.now()) : (_selectedEta ?? DateTime.now().add(const Duration(days: 20)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isEtd) {
          _selectedEtd = picked;
        } else {
          _selectedEta = picked;
        }
      });
    }
  }

  Future<void> _submitConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'booking_confirmation_no': _bookingNoController.text.trim(),
        'vessel_name': _vesselNameController.text.trim().isNotEmpty ? _vesselNameController.text.trim() : null,
        'voyage_number': _voyageNumberController.text.trim().isNotEmpty ? _voyageNumberController.text.trim() : null,
        if (_selectedEtd != null) 'etd': _selectedEtd!.toIso8601String(),
        if (_selectedEta != null) 'eta': _selectedEta!.toIso8601String(),
        'free_demurrage_days': int.tryParse(_freeDaysController.text.trim()) ?? 14,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      };

      await ref.read(freightBookingProvider.notifier).confirmBooking(widget.booking.bookingId, payload);

      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? '🟢 تم تأكيد حجز الشحن بنجاح (BK-01) وترقية المرحلة إلى STEP_07 وتغذية رادار فترات السماح'
                  : '🟢 Freight booking confirmed successfully (BK-01), stage upgraded to STEP_07, and free days radar populated',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? '❌ خطأ أثناء تأكيد الحجز: $e' : '❌ Error confirming booking: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final b = widget.booking;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: AppTheme.emerald, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'تأكيد حجز الشحن والناقل (BK-01)' : 'Confirm Freight Booking & Carrier (BK-01)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.charcoal,
                  ),
                ),
                Text(
                  isAr
                      ? 'رمز الحجز: ${b.bookingCode} | الناقل: ${b.shippingLineName ?? b.freightForwarderName ?? "TBA"}'
                      : 'Booking Code: ${b.bookingCode} | Carrier: ${b.shippingLineName ?? b.freightForwarderName ?? "TBA"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppTheme.cobalt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'تأكيد الحجز برقم التأكيد الفعلي (Booking No) ينقل ملف الشحنة تلقائياً إلى STEP_07 ويُغلق مهام BK-01 ويُنشئ مهمة متابعة فترات السماح (BK-02).'
                              : 'Confirming with the actual Booking No automatically transitions the shipment to STEP_07, closes BK-01 tasks, and creates the free days tracking task (BK-02).',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('bookingConfirmNoInput'),
                  controller: _bookingNoController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'رقم تأكيد الحجز (Booking No / Booking Confirmation)*'
                        : 'Booking Confirmation No. (Booking No)*',
                    hintText: isAr
                        ? 'e.g. MSC-CN-998822 أو COSCO-EGY-7711'
                        : 'e.g. MSC-CN-998822 or COSCO-EGY-7711',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isAr
                          ? 'يرجى إدخال رقم تأكيد الحجز من الخط الملاحي'
                          : 'Please enter booking confirmation number from shipping line';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('bookingVesselNameInput'),
                        controller: _vesselNameController,
                        decoration: InputDecoration(
                          labelText: isAr ? 'اسم السفينة (Vessel Name)' : 'Vessel Name',
                          hintText: 'e.g. MSC OSCAR / EVER GIVEN',
                          prefixIcon: const Icon(Icons.directions_boat_filled_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('bookingVoyageNoInput'),
                        controller: _voyageNumberController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isAr ? 'رقم الرحلة (Voyage No)' : 'Voyage No',
                          hintText: 'e.g. 2608W / 045E',
                          prefixIcon: const Icon(Icons.tag),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: isAr ? 'تاريخ الإبحار المتوقع (ETD)' : 'Estimated Departure (ETD)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedEtd != null
                                ? _selectedEtd!.toIso8601String().substring(0, 10)
                                : (isAr ? 'اختر تاريخ ETD' : 'Select ETD Date'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedEtd != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: isAr ? 'تاريخ الوصول المتوقع (ETA)' : 'Estimated Arrival (ETA)',
                            prefixIcon: const Icon(Icons.event_available_outlined),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedEta != null
                                ? _selectedEta!.toIso8601String().substring(0, 10)
                                : (isAr ? 'اختر تاريخ ETA' : 'Select ETA Date'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedEta != null ? null : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('bookingFreeDaysInput'),
                  controller: _freeDaysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'أيام السماح المجانية المتفق عليها (Free Demurrage Days)*'
                        : 'Agreed Free Demurrage Days*',
                    hintText: isAr ? '14 أو 21 يوم' : '14 or 21 days',
                    prefixIcon: const Icon(Icons.timelapse_outlined),
                    border: const OutlineInputBorder(),
                    suffixText: isAr ? 'يوم' : 'days',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isAr ? 'يرجى تحديد أيام السماح' : 'Please specify free days';
                    }
                    final parsed = int.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return isAr ? 'أدخل رقم صحيح موجب' : 'Please enter a positive integer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('bookingNotesInput'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isAr ? 'ملاحظات وتوجيهات الحجز (اختياري)' : 'Booking Directives / Notes (Optional)',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(isAr ? 'إلغاء' : 'Cancel'),
        ),
        ElevatedButton.icon(
          key: const Key('confirmBookingSubmitBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _submitConfirm,
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.verified, size: 18),
          label: Text(
            isAr ? 'تأكيد الحجز وتثبيته (BK-01)' : 'Confirm Booking (BK-01)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ================= VIEW BOOKING DIALOG =================
class _FreightBookingViewDialog extends StatelessWidget {
  final ShipmentBookingModel booking;
  const _FreightBookingViewDialog({required this.booking});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.visibility, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Text(l.freightBookingViewTitle(booking.bookingCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 750.0),
        height: 520,
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Text('${l.freightBookingViewShippingLine} ${booking.shippingLineName ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${l.freightBookingViewConfirmNo} ${booking.bookingConfirmationNo ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Route & Schedule
              Text(l.freightBookingViewRouteSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${l.freightBookingViewPol} ${booking.polName ?? "-" }')),
                          Expanded(child: Text('${l.freightBookingViewPod} ${booking.podName ?? "-" }')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: Text(l.freightBookingViewVesselVoyage(booking.vesselName ?? "-", booking.voyageNumber ?? "-"))),
                          Expanded(child: Text(l.freightBookingViewTransitTime(booking.transitTimeDays))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: Text(l.freightBookingViewEtd(booking.etd != null ? booking.etd!.substring(0, 10) : "-"))),
                          Expanded(child: Text(l.freightBookingViewEta(booking.eta != null ? booking.eta!.substring(0, 10) : "-"))),
                        ],
                      ),
                      if (booking.atd != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.freightBookingViewAtd(
                                  booking.atd!.substring(0, 10),
                                  booking.departureDelayDays > 0 ? "+${booking.departureDelayDays}d" : "0d",
                                ),
                                style: TextStyle(fontWeight: FontWeight.bold, color: booking.departureDelayDays > 0 ? Colors.red : Colors.green),
                              ),
                            ),
                            Expanded(child: Text(l.freightBookingViewExpectedWh(booking.expectedWarehouseArrivalDate != null ? booking.expectedWarehouseArrivalDate!.substring(0, 10) : "-"))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Containers
              Text(l.freightBookingViewContainersSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
              const SizedBox(height: 6),
              ...booking.containersData.map((c) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.quantity}x ${c.containerType} (${c.vgmWeightKg.toStringAsFixed(0)} kg)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...c.individualContainers.map((indiv) => Text('• ${indiv.containerNumber.isEmpty ? "-" : indiv.containerNumber} | ${indiv.sealNumber.isEmpty ? "-" : indiv.sealNumber}', style: const TextStyle(fontSize: 11))),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              // Charges Breakdown
              Text(l.freightBookingViewChargesSection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
              const SizedBox(height: 6),
              ...booking.costChargesData.map((ch) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('• ${ch.chargeType} (${ch.quantity}x ${ch.rate} ${ch.currency})'),
                      const Spacer(),
                      Text('${ch.total.toStringAsFixed(2)} ${ch.currency}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                children: [
                  Text(l.freightBookingViewTotalFreight, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('\$ ${booking.totalFreightCostUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.emerald)),
                ],
              ),
              if (booking.originalFreightCostUsd > 0 ||
                  booking.costSavingsUsd > 0 ||
                  booking.costVarianceUsd != 0.0)
                _buildCostSavingsComparisonCard(context, l),
            ],
          ),
        ),
        ),
      ),
      actions: [
        ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }

  Widget _buildCostSavingsComparisonCard(BuildContext context, AppLocalizations l) {
    final orig = booking.originalFreightCostUsd;
    final exec = booking.totalFreightCostUsd;
    final diff = (orig - exec).abs();
    final hasSavings = booking.hasSavings || (orig > 0 && exec < orig);
    final hasIncrease = booking.hasCostIncrease || (orig > 0 && exec > orig);
    final pct = orig > 0 ? (diff / orig * 100) : 0.0;

    final primaryColor = hasSavings
        ? AppTheme.emerald
        : (hasIncrease ? AppTheme.crimson : AppTheme.cobalt);
    final bgColor = hasSavings
        ? const Color(0xFFF0FDF4)
        : (hasIncrease ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC));
    final borderColor = hasSavings
        ? Colors.green.shade300
        : (hasIncrease ? Colors.red.shade300 : Colors.blueGrey.shade200);

    final breakdownList = (booking.quotationDetailsData['savings_breakdown'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSavings
                      ? Icons.savings_outlined
                      : (hasIncrease ? Icons.trending_up : Icons.compare_arrows),
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSavings
                          ? l.freightBookingCostSavingsTitle
                          : (hasIncrease
                              ? l.freightBookingCostIncreaseTitle
                              : l.freightBookingNoPriceVariance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                    if (booking.scenarioProviderName != null && booking.scenarioProviderName!.isNotEmpty)
                      Text(
                        l.freightBookingBasedOnQuote(booking.scenarioProviderName!),
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasSavings
                      ? l.freightBookingCostSavingsBadgeAmount(diff.toStringAsFixed(2), pct.toStringAsFixed(1))
                      : (hasIncrease
                          ? l.freightBookingCostIncreaseBadgeAmount(diff.toStringAsFixed(2))
                          : l.freightBookingCostMatchBadge),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 3-Column Comparison: Original Quoted Price | Executed Booking Price | Net Difference
          Row(
            children: [
              // Column 1: Original Quoted Price
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.freightBookingOriginalQuotedPrice,
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$ ${orig.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoal,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Column 2: Executed Booking Price
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.freightBookingExecutedPrice,
                        style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$ ${exec.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Column 3: Savings / Variance
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasSavings ? Colors.green.shade50 : (hasIncrease ? Colors.red.shade50 : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSavings ? l.freightBookingCostSavingsBadge : (hasIncrease ? l.freightBookingCostIncreaseBadge : l.freightBookingNetDifference),
                        style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hasSavings ? "-" : "+"}\$ ${diff.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Savings breakdown or Multiplier Details
          if (breakdownList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.freightBookingBreakdownHeader,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                  const SizedBox(height: 4),
                  ...breakdownList.map((item) {
                    final cName = item['charge_type'] ?? '';
                    final oRate = (item['original_unit_rate'] as num?)?.toDouble() ?? 0.0;
                    final eRate = (item['executed_unit_rate'] as num?)?.toDouble() ?? 0.0;
                    final uDiff = (item['unit_diff'] as num?)?.toDouble() ?? 0.0;
                    final qty = item['quantity'] ?? 1;
                    final uType = item['unit_type'] ?? '';
                    final iSavings = (item['item_savings'] as num?)?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        l.freightBookingBreakdownSavingsUnit(
                          cName,
                          oRate.toStringAsFixed(2),
                          eRate.toStringAsFixed(2),
                          uDiff.toStringAsFixed(2),
                          qty.toString(),
                          uType,
                          iSavings.toStringAsFixed(2),
                        ),
                        style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else if (booking.savingsNotes != null && booking.savingsNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                '💡 ${booking.savingsNotes}',
                style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================= PRINT BOOKING MANIFEST DIALOG =================
class _FreightBookingPrintDialog extends StatelessWidget {
  final ShipmentBookingModel booking;
  const _FreightBookingPrintDialog({required this.booking});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.print, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(l.freightBookingPrintTitle(booking.bookingCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 700.0),
        height: 520,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: SelectionArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(l.freightBookingPrintSystemHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1)),
                        Text(l.freightBookingPrintManifestHeader(booking.bookingCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(l.freightBookingPrintDate(DateTime.now().toIso8601String().substring(0, 16).replaceAll("T", " ")), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: Text('${l.freightBookingViewShippingLine} ${booking.shippingLineName ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('${l.freightBookingViewConfirmNo} ${booking.bookingConfirmationNo ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text('${l.freightBookingColVesselVoyage}: ${booking.vesselName ?? "-"} / ${booking.voyageNumber ?? "-"}')),
                    Expanded(child: Text('${l.freightBookingColRoute}: ${booking.polName ?? "-"} ➔ ${booking.podName ?? "-"}')),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text(l.freightBookingViewEtd(booking.etd != null ? booking.etd!.substring(0, 10) : "-"))),
                    Expanded(child: Text(l.freightBookingViewEta(booking.eta != null ? booking.eta!.substring(0, 10) : "-"))),
                  ],
                ),
                if (booking.atd != null) ...[
                  const SizedBox(height: 6),
                  Text(l.freightBookingViewAtd(booking.atd!.substring(0, 10), '+${booking.departureDelayDays}d')),
                ],

                const SizedBox(height: 12),
                Text(l.freightBookingPrintContainersHeader, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                const SizedBox(height: 4),
                ...booking.containersData.expand((c) => c.individualContainers.map((indiv) => Text('• ${c.containerType} | ${indiv.containerNumber.isEmpty ? "N/A" : indiv.containerNumber} | ${indiv.sealNumber.isEmpty ? "N/A" : indiv.sealNumber}'))),

                const SizedBox(height: 12),
                Text(l.freightBookingPrintChargesHeader, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                const SizedBox(height: 4),
                ...booking.costChargesData.map((ch) => Text('• ${ch.chargeType}: ${ch.total.toStringAsFixed(2)} ${ch.currency}')),
                const Divider(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.freightBookingPrintGrandTotal(booking.totalFreightCostUsd.toStringAsFixed(2)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.emerald)),
                ),
                if (booking.originalFreightCostUsd > 0 || booking.costSavingsUsd > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings_outlined, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${l.freightBookingOriginalQuotedPrice}: \$${booking.originalFreightCostUsd.toStringAsFixed(2)} | ${l.freightBookingExecutedPrice}: \$${booking.totalFreightCostUsd.toStringAsFixed(2)} | ${l.freightBookingCostSavingsBadge}: \$${booking.costSavingsUsd.toStringAsFixed(2)} (${booking.savingsPercent.toStringAsFixed(1)}%)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.green),
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
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
        TextButton.icon(
          icon: const Icon(Icons.copy_outlined, size: 16),
          label: Text(l.copyTooltip),
          onPressed: () {
            final lines = <String>[
              l.freightBookingPrintSystemHeader,
              '${l.freightBookingColBookingCode}: ${booking.bookingCode}',
              '${l.freightBookingViewShippingLine} ${booking.shippingLineName ?? "-"}',
              '${l.freightBookingViewConfirmNo} ${booking.bookingConfirmationNo ?? "-"}',
              '${l.freightBookingColRoute}: ${booking.polName ?? "-"} → ${booking.podName ?? "-"}',
              '${l.freightBookingColVesselVoyage}: ${booking.vesselName ?? "-"} / ${booking.voyageNumber ?? "-"}',
              l.freightBookingViewEtd(booking.etd != null ? booking.etd!.substring(0, 10) : '-'),
              l.freightBookingViewEta(booking.eta != null ? booking.eta!.substring(0, 10) : '-'),
              ...booking.containersData.expand((c) => c.individualContainers.map((i) => '${c.containerType} | ${i.containerNumber} | ${i.sealNumber}')),
              ...booking.costChargesData.map((ch) => '${ch.chargeType}: ${ch.total.toStringAsFixed(2)} ${ch.currency}'),
              '${l.freightBookingViewTotalFreight}: \$${booking.totalFreightCostUsd.toStringAsFixed(2)}',
            ];
            CopyHelper.copy(context, lines.join('\n'));
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🖨️ ${l.freightBookingPrintSuccess}'), backgroundColor: AppTheme.emerald));
            Navigator.pop(context);
          },
          icon: const Icon(Icons.print, color: Colors.white),
          label: Text(l.freightBookingPrintNowBtn, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
