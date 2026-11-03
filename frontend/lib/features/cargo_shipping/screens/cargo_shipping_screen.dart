import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../providers/cargo_shipping_provider.dart';
import '../widgets/cargo_shipping_form_tab.dart';
import '../widgets/saved_cargo_shipping_registry_tab.dart';

class CargoShippingScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;

  const CargoShippingScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
  });

  @override
  ConsumerState<CargoShippingScreen> createState() => _CargoShippingScreenState();
}

class _CargoShippingScreenState extends ConsumerState<CargoShippingScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  final GlobalKey<CargoShippingFormTabState> _formTabKey = GlobalKey<CargoShippingFormTabState>();
  int _activeStepIndex = 0;
  final Set<int> _visitedMainTabs = {0};

  @override
  void initState() {
    super.initState();
    _activeStepIndex = widget.initialSubTab.clamp(0, 1);
    _mainTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        if (!_visitedMainTabs.contains(_mainTabController.index)) {
          setState(() {
            _visitedMainTabs.add(_mainTabController.index);
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void didUpdateWidget(covariant CargoShippingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() {
        _activeStepIndex = widget.initialSubTab.clamp(0, 1);
        _mainTabController.index = 0;
        _visitedMainTabs.add(0);
      });
    }
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    if (!ref.read(cargoShippingProvider).isLoading) {
      ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.local_shipping_outlined,
        titleEn: 'Loading & Tracking Form',
        titleAr: 'تجهيز الشحن ومتابعة التحميل',
      ),
      const VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Saved Cargo Registry',
        titleAr: 'سجل متابعة الشحنات والتحميل',
      ),
    ];
    final isTrackingTab = _activeStepIndex == 1;

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: isTrackingTab ? 'STEP-08' : 'STEP-07',
        titleEn: isTrackingTab ? 'Cargo Shipping Tracking (48h SLA)' : 'Freight Allocations & Cargo Shipping (VGM)',
        titleAr: isTrackingTab ? context.l10n.cargoShippingSlaStageTitle : context.l10n.cargoShippingAllocationsTitle,
        headerIcon: isTrackingTab ? Icons.directions_boat_outlined : Icons.grid_view_outlined,
        headerColor: isTrackingTab ? AppTheme.cobalt : AppTheme.emerald,
        tabs: tabs,
        selectedIndex: _mainTabController.index,
        onTabSelected: (index) => setState(() {
          _mainTabController.index = index;
          _visitedMainTabs.add(index);
        }),
        selectedImportFileId: widget.initialImportFileId,
        onShipmentStatusChanged: () {
          ref.read(importFilesProvider.notifier).fetchImportFiles();
        },
        headerActions: [
          AppButton(
            label: context.l10n.cargoShippingAiExtractorBtn,
            icon: Icons.auto_awesome,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SelectionArea(
                  child: SmartInvoiceBLExtractorDialog(
                    initialImportFileId: _formTabKey.currentState?.selectedImportFileId ?? widget.initialImportFileId,
                    initialTabIndex: 1,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          SmartUploadButton(
            module: SmartUploadModule.cargoShipping,
            label: context.l10n.cargoShippingUploadBlLabel,
            onDataExtracted: (result) {
              final fields = result.extractedFields;
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(
                  context,
                  context.l10n.cargoShippingUploadBlSuccess(fields['bl_number'] ?? 'N/A'),
                  severity: AppSeverity.success,
                  duration: const Duration(seconds: 5),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.70)),
            tooltip: context.l10n.liveReload,
            onPressed: _refreshAllData,
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
        ],
        body: IndexedStack(
          index: _mainTabController.index,
          children: [
            _visitedMainTabs.contains(0)
                ? CargoShippingFormTab(
                    key: _formTabKey,
                    initialSubTab: widget.initialSubTab,
                    initialImportFileId: widget.initialImportFileId,
                    onStepChanged: (step) => setState(() => _activeStepIndex = step),
                    onSwitchToRegistry: () => _mainTabController.animateTo(1),
                    onRefreshNeeded: _refreshAllData,
                  )
                : const SizedBox.shrink(),
            _visitedMainTabs.contains(1)
                ? SavedCargoShippingRegistryTab(
                    onEditRecord: (rec) {
                      _formTabKey.currentState?.loadRecordForEditing(rec);
                      _mainTabController.animateTo(0);
                    },
                    onCreateNewRecord: () {
                      _formTabKey.currentState?.resetForm();
                      _mainTabController.animateTo(0);
                    },
                    onCloneRecordToForm: (rec, newCode, containers) {
                      _formTabKey.currentState?.loadClonedRecord(rec, newCode, containers);
                      _mainTabController.animateTo(0);
                    },
                    onRefreshNeeded: _refreshAllData,
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
