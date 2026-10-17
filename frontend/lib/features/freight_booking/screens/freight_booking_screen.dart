import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_documentation/widgets/draft_bl_review_dialog.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/freight_booking_model.dart';
import '../providers/freight_booking_provider.dart';
import '../widgets/departure_confirmation_dialog.dart';
import '../widgets/freight_booking_confirm_dialog.dart';
import '../widgets/freight_booking_form_dialog.dart';
import '../widgets/freight_booking_print_dialog.dart';
import '../widgets/freight_booking_prompts.dart';
import '../widgets/freight_booking_registry_row.dart';
import '../widgets/freight_booking_toolbar.dart';
import '../widgets/freight_booking_ui.dart';
import '../widgets/freight_booking_view_dialog.dart';
import '../widgets/search_and_clone_freight_booking_dialog.dart';

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

  void _showAddEditBookingDialog([ShipmentBookingModel? bookingToEdit, bool isClone = false]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FreightBookingFormDialog(bookingToEdit: bookingToEdit, isClone: isClone),
    );
  }

  void _showViewBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => FreightBookingViewDialog(booking: booking),
    );
  }

  void _showPrintBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => FreightBookingPrintDialog(booking: booking),
    );
  }

  void _showConfirmBookingDialog(ShipmentBookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FreightBookingConfirmDialog(booking: booking),
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
    showDialog(
      context: context,
      builder: (dialogCtx) => SearchAndCloneFreightBookingDialog(
        bookings: bookings,
        onSelectBooking: (selected) => _onCloneBooking(selected),
      ),
    );
  }

  Future<void> _confirmDelete(ShipmentBookingModel bkg) async {
    final l = context.l10n;
    final confirmed = await FbkPrompts.confirmDelete(context, bkg.bookingCode);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(freightBookingProvider.notifier).softDeleteBooking(bkg.bookingId);
    } catch (e) {
      if (mounted) {
        FbkUi.snack(context, '${l.error}: ${ApiErrorText.of(l, e)}', severity: AppSeverity.danger);
      }
    }
  }

  void _onCloneBooking(ShipmentBookingModel booking) {
    final l = AppLocalizations.of(context);
    final newDraftCode = 'BK-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (dialogCtx) => CloneEntityReviewDialog(
        entityType: l.fbkCloneEntityType,
        sourceCode: booking.bookingCode,
        suggestedNewCode: newDraftCode,
        sourceTitle: '${booking.shippingLineName ?? "—"} (${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"})',
        copiedFieldsSummary: {
          l.freightBookingColCarrierForwarder: '${booking.shippingLineName ?? "—"} / ${booking.freightForwarderName ?? "—"}',
          l.freightBookingColRoute: '${booking.polName ?? "—"} ➔ ${booking.podName ?? "—"}',
          l.freightBookingColContainers: booking.containersData.map((c) => "${c.quantity}x ${c.containerType}").join(", "),
          l.freightBookingColTotalFreight: booking.totalFreightCostUsd == null ? CcFormat.unknown : '\$${booking.totalFreightCostUsd!.toStringAsFixed(2)} USD',
        },
        mandatorilyResetFields: [
          l.fbkCloneReset1,
          l.fbkCloneReset2,
          l.fbkCloneReset3,
          l.fbkCloneReset4,
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
            FbkUi.snack(context, '${l.cloneBookingRowTooltip}: $newCode', severity: AppSeverity.info);
            _showAddEditBookingDialog(cloned, true);
          }
        },
      ),
    );
  }

  List<String> _tsvHeaders(AppLocalizations l) => [
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

  List<String> _tsvRow(ShipmentBookingModel b) => [
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
        CcFormat.fixed(b.totalFreightCostUsd),
        b.status,
      ];

  void _copyBookingRowTsv(ShipmentBookingModel bkg, AppLocalizations l) {
    TableCopyHelper.copyRow(
      context,
      _tsvRow(bkg),
      headers: _tsvHeaders(l),
      includeHeaders: true,
      customMessage: l.copyBookingRowSuccess,
    );
  }

  void _copyBookingsTableTsv(List<ShipmentBookingModel> bookings, AppLocalizations l) {
    TableCopyHelper.copyTable(
      context,
      _tsvHeaders(l),
      bookings.map(_tsvRow).toList(),
      customMessage: l.copyBookingsTableSuccess,
    );
  }

  Future<void> _exportBookingsExcel(List<ShipmentBookingModel> bookings, AppLocalizations l) async {
    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Freight Booking',
      importFileNameOrCode: 'Registry',
      headers: _tsvHeaders(l),
      rows: bookings.map(_tsvRow).toList(),
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
      b.totalFreightCostUsd == null ? CcFormat.unknown : '\$${b.totalFreightCostUsd!.toStringAsFixed(2)}',
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
          'Total USD': '\$${bookings.fold(0.0, (acc, b) => acc + (b.totalFreightCostUsd ?? 0)).toStringAsFixed(2)}',
        },
      ),
    );
  }

  Widget _metrics(AppLocalizations l, List<ShipmentBookingModel> bookings) {
    final delayed = bookings.where((b) => b.departureDelayDays > 0).length;
    return CcUi.metrics([
      MetricCardData(
        title: l.fbkMetricBookings,
        value: '${bookings.length}',
        icon: Icons.directions_boat_outlined,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.freightBookingStatusConfirmed,
        value: '${bookings.where((b) => b.status == 'Confirmed').length}',
        icon: Icons.verified_outlined,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.freightBookingStatusSailed,
        value: '${bookings.where((b) => b.status == 'Sailed').length}',
        icon: Icons.sailing_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.fbkMetricDelayed,
        value: '$delayed',
        icon: Icons.alarm_off,
        color: delayed > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
      ),
    ]);
  }

  Widget _registry(AppLocalizations l, List<ShipmentBookingModel> bookings, List<ImportFileModel> importFiles) {
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};
    final isAr = l.isArabic;
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
        itemBuilder: (context, i) {
          final bkg = bookings[i];
          final f = bkg.importFileId != null ? importFilesMap[bkg.importFileId] : null;
          final rawCode = bkg.importFileCode ?? (bkg.importFileId != null ? 'IMP-${bkg.importFileId}' : '');
          final shipName = f != null
              ? DisplayNameResolver.resolveShipmentName(f, isArabic: isAr)
              : DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isAr);
          final shipTitle = f != null
              ? DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr)
              : DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
          return FbkRegistryRow(
            booking: bkg,
            fileName: shipName,
            fileCode: rawCode,
            fileTitle: shipTitle,
            actions: FbkRowActions(
              onView: () => _showViewBookingDialog(bkg),
              onEdit: () => _showAddEditBookingDialog(bkg),
              onClone: () => _onCloneBooking(bkg),
              onPrint: () => _showPrintBookingDialog(bkg),
              onDelete: () => _confirmDelete(bkg),
              onCopyRow: () => _copyBookingRowTsv(bkg, l),
              onConfirmBooking: () => _showConfirmBookingDialog(bkg),
              onDeparture: () => _showDepartureConfirmationDialog(bkg),
              onReviewDraftBl: () => _showDraftBlReviewDialog(bkg),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bookingsState = ref.watch(freightBookingProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? <ImportFileModel>[];

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

    final shipmentChip = _selectedImportFileId == null
        ? null
        : l.fbkFilterShipmentChip(
            importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull?.importFileCode ??
                '#$_selectedImportFileId');

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
        FbkUi.fit(AppButton(
          label: l.freightBookingAiShippingLineBtn,
          icon: Icons.directions_boat_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => UniversalEntityExtractorDialog.showShippingLineExtractor(
            context,
            onSaved: () {
              ref.read(partnersProvider.notifier).fetchPartners();
              ref.read(allPartnersProvider.notifier).fetchPartners();
            },
          ),
        )),
        const SizedBox(width: 8),
        FbkUi.fit(AppButton(
          label: l.freightBookingAiForwarderBtn,
          icon: Icons.local_shipping_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => UniversalEntityExtractorDialog.showFreightForwarderExtractor(
            context,
            onSaved: () {
              ref.read(partnersProvider.notifier).fetchPartners();
              ref.read(allPartnersProvider.notifier).fetchPartners();
            },
          ),
        )),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.70)),
          tooltip: l.freightBookingBtnLiveReload,
          onPressed: _refreshData,
        ),
      ],
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Data Actions Toolbar
              MasterDataToolbarWidget(
                moduleEndpoint: 'freight-booking',
                title: 'Freight_Bookings',
                onRefreshNeeded: () => ref.read(freightBookingProvider.notifier).fetchBookings(),
              ),
              const SizedBox(height: 12),

              // Registry metrics (loaded values only)
              if (bookingsState.valueOrNull != null) ...[
                _metrics(l, bookingsState.valueOrNull!),
                const SizedBox(height: 12),
              ],

              FbkActionBar(
                onCreate: () => _showAddEditBookingDialog(),
                onSearchClone: () => _openSearchAndCloneDialog(bookingsState.valueOrNull ?? []),
                onCopyTable: () => _copyBookingsTableTsv(bookingsState.valueOrNull ?? [], l),
                onExportExcel: () => _exportBookingsExcel(bookingsState.valueOrNull ?? [], l),
                onExportPdf: () => _exportBookingsPdf(bookingsState.valueOrNull ?? [], l),
              ),
              const SizedBox(height: 12),

              FbkFilterBar(
                searchController: _searchController,
                status: _selectedStatusFilter,
                shipmentChipLabel: shipmentChip,
                onSearchChanged: (val) {
                  ref.read(freightBookingProvider.notifier).fetchBookings(search: val, status: _selectedStatusFilter);
                },
                onStatusChanged: (val) {
                  setState(() => _selectedStatusFilter = val);
                  ref.read(freightBookingProvider.notifier).fetchBookings(search: _searchController.text, status: val);
                },
                onClearShipment: () {
                  setState(() => _selectedImportFileId = null);
                  ref.read(freightBookingProvider.notifier).fetchBookings(
                        search: _searchController.text,
                        status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
                      );
                },
              ),
              const SizedBox(height: 16),

              // Smart Experience Guide Alert Banner
              if (_guideMatchResult != null && _guideMatchResult!.matchedEntries.isNotEmpty)
                ExperienceGuideAlertBanner(
                  matchResult: _guideMatchResult!,
                ),

              // Bookings registry
              bookingsState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: AppLoadingState(),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: AppErrorState(
                    message: '${l.error}: $err',
                    onRetry: _refreshData,
                  ),
                ),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: AppEmptyState(
                        message: l.freightBookingEmptyRecords,
                        icon: Icons.directions_boat_outlined,
                        actionLabel: l.freightBookingCreateButton,
                        onAction: () => _showAddEditBookingDialog(),
                      ),
                    );
                  }
                  return _registry(l, bookings, importFiles);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
