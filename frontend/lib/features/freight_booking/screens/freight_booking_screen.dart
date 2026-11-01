import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../providers/freight_booking_provider.dart';
import '../widgets/freight_booking_toolbar.dart';
import '../widgets/freight_booking_ui.dart';
import '../widgets/screen/freight_booking_dialog_helper.dart';
import '../widgets/screen/freight_booking_export_helper.dart';
import '../widgets/screen/freight_booking_metrics.dart';
import '../widgets/screen/freight_booking_registry_list.dart';

class FreightBookingScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const FreightBookingScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<FreightBookingScreen> createState() => _FreightBookingScreenState();
}

class _FreightBookingScreenState extends ConsumerState<FreightBookingScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _selectedStatusFilter = 'All';
  int? _selectedImportFileId;
  GuideMatchResultModel? _guideMatchResult;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() {
      ref.read(freightBookingProvider.notifier).fetchBookings(
        importFileId: _selectedImportFileId,
        status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
      );
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
    ref.read(freightBookingProvider.notifier).refresh();
    ref.read(shippingScenariosProvider.notifier).fetchSessions();
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
          FreightBookingDialogHelper.showAddEditBookingDialog(context);
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
                onRefreshNeeded: () => ref.read(freightBookingProvider.notifier).refresh(),
              ),
              const SizedBox(height: 12),

              // Registry metrics (loaded values only)
              if (bookingsState.valueOrNull != null) ...[
                FreightBookingMetrics(bookings: bookingsState.valueOrNull!),
                const SizedBox(height: 12),
              ],

              FbkActionBar(
                onCreate: () => FreightBookingDialogHelper.showAddEditBookingDialog(context),
                onSearchClone: () => FreightBookingDialogHelper.openSearchAndCloneDialog(
                  context: context,
                  bookings: bookingsState.valueOrNull ?? [],
                  onClone: (selected) => FreightBookingDialogHelper.onCloneBooking(
                    context: context,
                    booking: selected,
                  ),
                ),
                onCopyTable: () => FreightBookingExportHelper.copyBookingsTableTsv(
                  context: context,
                  bookings: bookingsState.valueOrNull ?? [],
                  l: l,
                ),
                onExportExcel: () => FreightBookingExportHelper.exportBookingsExcel(
                  context: context,
                  bookings: bookingsState.valueOrNull ?? [],
                  l: l,
                ),
                onExportPdf: () => FreightBookingExportHelper.exportBookingsPdf(
                  context: context,
                  bookings: bookingsState.valueOrNull ?? [],
                  l: l,
                ),
              ),
              const SizedBox(height: 12),

              FbkFilterBar(
                searchController: _searchController,
                status: _selectedStatusFilter,
                shipmentChipLabel: shipmentChip,
                onSearchChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                    ref.read(freightBookingProvider.notifier).fetchBookings(
                      search: val,
                      status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
                      importFileId: _selectedImportFileId,
                    );
                  });
                },
                onStatusChanged: (val) {
                  setState(() => _selectedStatusFilter = val);
                  ref.read(freightBookingProvider.notifier).fetchBookings(
                    search: _searchController.text,
                    status: val != 'All' ? val : null,
                    importFileId: _selectedImportFileId,
                  );
                },
                onClearShipment: () {
                  setState(() => _selectedImportFileId = null);
                  ref.read(freightBookingProvider.notifier).fetchBookings(
                    search: _searchController.text,
                    status: _selectedStatusFilter != 'All' ? _selectedStatusFilter : null,
                    importFileId: null,
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
                        onAction: () => FreightBookingDialogHelper.showAddEditBookingDialog(context),
                      ),
                    );
                  }
                  final bookingNotifier = ref.read(freightBookingProvider.notifier);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FreightBookingRegistryList(
                        bookings: bookings,
                        importFiles: importFiles,
                        onRefresh: _refreshData,
                      ),
                      ListLoadMoreFooter(
                        loaded: bookings.length,
                        total: bookingNotifier.totalCount,
                        hasMore: bookingNotifier.hasMore,
                        onLoadMore: bookingNotifier.loadMore,
                      ),
                    ],
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
