import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/import_file_scope_selector.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import 'split_shipments_provider.dart';
import 'widgets/bl_allocation_splitter_card.dart';
import 'widgets/prorated_cost_pool_dialog.dart';
import 'widgets/prorated_cost_preview_card.dart';
import 'widgets/unallocated_po_items_table.dart';

/// Coordinator screen for Split Shipments & Multi-PO fulfillment (Type A Stage Screen).
class SplitShipmentsScreen extends ConsumerStatefulWidget {
  /// Import file to open on; null shows the file picker's empty state.
  final int? shipmentId;

  const SplitShipmentsScreen({
    super.key,
    this.shipmentId,
  });

  @override
  ConsumerState<SplitShipmentsScreen> createState() => _SplitShipmentsScreenState();
}

class _SplitShipmentsScreenState extends ConsumerState<SplitShipmentsScreen> {
  int _currentTabIndex = 0;
  UnallocatedPoItem? _itemToAllocate;

  late int? _fileId = widget.shipmentId;

  void _selectFile(int? fileId) {
    setState(() {
      _fileId = fileId;
      _itemToAllocate = null;
      _currentTabIndex = 0;
    });
  }

  void _invalidateFileData() {
    ref.invalidate(splitAllocationsListProvider);
    ref.invalidate(unallocatedPoItemsProvider);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ApiErrorText.of(context.l10n, error)),
        backgroundColor: AppTheme.crimson,
      ),
    );
  }

  void _handleAllocateItem(UnallocatedPoItem item) {
    setState(() {
      _itemToAllocate = item;
      _currentTabIndex = 1; // Switch to Splitter tab
    });
  }

  void _handleConfirmSplit(Map<String, dynamic> payload) async {
    final fileId = _fileId;
    final item = _itemToAllocate;
    if (fileId == null) return;
    if (item != null) {
      payload['po_id'] = item.poId;
      payload['po_item_id'] = item.poItemId;
      payload['total_item_quantity'] = item.totalQuantity;
    }
    try {
      await ref.read(splitShipmentsRepositoryProvider).createAllocation(fileId, payload);
    } catch (e) {
      _showError(e);
      return;
    }
    _invalidateFileData();
    if (!mounted) return;
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
    final fileId = _fileId;
    if (fileId == null) return;
    final pools = await showProratedCostPoolDialog(context);
    if (pools == null) return;
    try {
      await ref.read(splitShipmentsRepositoryProvider).recalculateProratedCosts(
            fileId,
            customsPool: pools.$1,
            freightPool: pools.$2,
          );
    } catch (e) {
      _showError(e);
      return;
    }
    _invalidateFileData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة احتساب وتحديث مجمع التكاليف التناسبية بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileId = _fileId;

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

    final Widget bodyWidget = fileId == null ? const ImportFileRequiredState() : _buildFileBody(fileId);

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
        selectedImportFileId: fileId,
        topBanner: ImportFileScopeSelector(
          selectedImportFileId: fileId,
          onChanged: _selectFile,
        ),
        headerActions: [
          AppButton(
            label: 'تحديث',
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: fileId == null ? null : _invalidateFileData,
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: bodyWidget,
        ),
      ),
    );
  }

  Widget _buildFileBody(int fileId) {
    switch (_currentTabIndex) {
      case 0:
        return ref.watch(unallocatedPoItemsProvider(fileId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  ApiErrorText.of(context.l10n, err),
                  style: const TextStyle(color: AppTheme.crimson),
                ),
              ),
              data: (result) => UnallocatedPoItemsTable(
                items: result.items,
                onAllocate: _handleAllocateItem,
              ),
            );
      case 1:
        final parentBl = ref.watch(unallocatedPoItemsProvider(fileId)).valueOrNull?.blNumber ?? '';
        return BlAllocationSplitterCard(
          key: ValueKey('splitter-$fileId-${_itemToAllocate?.poItemId}-$parentBl'),
          initialParentBl: parentBl,
          initialSku: _itemToAllocate?.itemSku,
          maxQuantity: _itemToAllocate?.remainingQuantity,
          onConfirmSplit: _handleConfirmSplit,
          onCancel: () => setState(() => _currentTabIndex = 0),
        );
      case 2:
      default:
        return ref.watch(splitAllocationsListProvider(fileId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  ApiErrorText.of(context.l10n, err),
                  style: const TextStyle(color: AppTheme.crimson),
                ),
              ),
              data: (result) => ProratedCostPreviewCard(
                allocations: result.items,
                onRecalculatePool: _handleRecalculatePool,
              ),
            );
    }
  }
}
