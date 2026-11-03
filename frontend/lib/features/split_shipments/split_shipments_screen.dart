import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import 'split_shipments_provider.dart';
import 'widgets/bl_allocation_splitter_card.dart';
import 'widgets/prorated_cost_preview_card.dart';
import 'widgets/unallocated_po_items_table.dart';

/// Coordinator screen for Split Shipments & Multi-PO fulfillment (Type A Stage Screen).
class SplitShipmentsScreen extends ConsumerStatefulWidget {
  final int shipmentId;

  const SplitShipmentsScreen({
    super.key,
    this.shipmentId = 1,
  });

  @override
  ConsumerState<SplitShipmentsScreen> createState() => _SplitShipmentsScreenState();
}

class _SplitShipmentsScreenState extends ConsumerState<SplitShipmentsScreen> {
  int _currentTabIndex = 0;
  UnallocatedPoItem? _itemToAllocate;

  // Mock list of PO items for demonstration and allocation
  final List<UnallocatedPoItem> _samplePoItems = [
    UnallocatedPoItem(
      poItemId: 1,
      poId: 10,
      poNumber: 'PO-2026-4401',
      itemSku: 'SKU-INVERTER-5KW',
      itemName: 'محول تيار شمسي 5 كيلوواط',
      totalQuantity: 200,
      allocatedQuantity: 80,
    ),
    UnallocatedPoItem(
      poItemId: 2,
      poId: 10,
      poNumber: 'PO-2026-4401',
      itemSku: 'SKU-PANEL-450W',
      itemName: 'ألواح طاقة شمسية 450 واط',
      totalQuantity: 1000,
      allocatedQuantity: 400,
    ),
    UnallocatedPoItem(
      poItemId: 3,
      poId: 11,
      poNumber: 'PO-2026-4402',
      itemSku: 'SKU-CABLE-6MM',
      itemName: 'كابلات طاقة شمسية 6 مم',
      totalQuantity: 5000,
      allocatedQuantity: 2500,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(splitShipmentIdProvider.notifier).state = widget.shipmentId;
    });
  }

  void _handleAllocateItem(UnallocatedPoItem item) {
    setState(() {
      _itemToAllocate = item;
      _currentTabIndex = 1; // Switch to Splitter tab
    });
  }

  void _handleConfirmSplit(Map<String, dynamic> payload) async {
    final repo = ref.read(splitShipmentsRepositoryProvider);
    await repo.createAllocation(widget.shipmentId, payload);
    ref.invalidate(splitAllocationsListProvider);
    setState(() {
      _itemToAllocate = null;
      _currentTabIndex = 2; // Switch to Prorated Costs tab
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل تجزئة البوليصة وتخصيص البند بنجاح')),
      );
    }
  }

  void _handleRecalculatePool() async {
    final repo = ref.read(splitShipmentsRepositoryProvider);
    await repo.recalculateProratedCosts(
      widget.shipmentId,
      customsPool: 150000.0,
      freightPool: 60000.0,
    );
    ref.invalidate(splitAllocationsListProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة احتساب وتحديث مجمع التكاليف التناسبية بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allocationsAsync = ref.watch(splitAllocationsListProvider);

    const tabs = [
      VerticalNavTabItem(
        icon: Icons.list_alt,
        titleAr: 'بنود أوامر الشراء',
        titleEn: 'PO Line Items',
      ),
      VerticalNavTabItem(
        icon: Icons.call_split,
        titleAr: 'تجزئة البوالص',
        titleEn: 'Split B/L Form',
      ),
      VerticalNavTabItem(
        icon: Icons.pie_chart,
        titleAr: 'التكاليف التناسبية',
        titleEn: 'Prorated Costs',
      ),
    ];

    Widget bodyWidget;
    switch (_currentTabIndex) {
      case 0:
        bodyWidget = UnallocatedPoItemsTable(
          items: _samplePoItems,
          onAllocate: _handleAllocateItem,
        );
        break;
      case 1:
        bodyWidget = BlAllocationSplitterCard(
          initialParentBl: 'MEDU-99887766',
          initialSku: _itemToAllocate?.itemSku,
          maxQuantity: _itemToAllocate?.remainingQuantity,
          onConfirmSplit: _handleConfirmSplit,
          onCancel: () => setState(() => _currentTabIndex = 0),
        );
        break;
      case 2:
      default:
        bodyWidget = allocationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('خطأ في تحميل التكاليف: $err')),
          data: (result) => ProratedCostPreviewCard(
            allocations: result.items,
            onRecalculatePool: _handleRecalculatePool,
          ),
        );
        break;
    }

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'SPLIT-BL',
        titleAr: 'تجزئة بوالص الشحن وتوزيع بنود أوامر الشراء',
        titleEn: 'Split Shipments & Multi-PO Allocations',
        headerIcon: Icons.alt_route,
        headerColor: AppTheme.cobalt,
        tabs: tabs,
        selectedIndex: _currentTabIndex,
        onTabSelected: (index) => setState(() => _currentTabIndex = index),
        selectedImportFileId: widget.shipmentId,
        headerActions: [
          AppButton(
            label: 'تحديث',
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: () => ref.invalidate(splitAllocationsListProvider),
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: bodyWidget,
        ),
      ),
    );
  }
}
