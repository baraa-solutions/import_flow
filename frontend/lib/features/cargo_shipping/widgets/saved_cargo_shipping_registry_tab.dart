import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/cargo_shipping_model.dart';
import '../providers/cargo_shipping_provider.dart';
import 'registry/cargo_shipping_clone_dialog_helper.dart';
import 'registry/cargo_shipping_registry_export_helper.dart';
import 'registry/cargo_shipping_registry_table_columns.dart';
import 'registry/cargo_shipping_registry_toolbar.dart';

class SavedCargoShippingRegistryTab extends ConsumerStatefulWidget {
  final void Function(CargoShippingModel rec) onEditRecord;
  final VoidCallback onCreateNewRecord;
  final VoidCallback onRefreshNeeded;
  final void Function(
    CargoShippingModel sourceRec,
    String newCode,
    List<ContainerLoadingModel> clonedContainers,
  )? onCloneRecordToForm;

  const SavedCargoShippingRegistryTab({
    super.key,
    required this.onEditRecord,
    required this.onCreateNewRecord,
    required this.onRefreshNeeded,
    this.onCloneRecordToForm,
  });

  @override
  ConsumerState<SavedCargoShippingRegistryTab> createState() => _SavedCargoShippingRegistryTabState();
}

class _SavedCargoShippingRegistryTabState extends ConsumerState<SavedCargoShippingRegistryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _registryStatusFilter = 'All';
  String _registrySlaFilter = 'All';
  String _registryActiveFilter = 'Active';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteRecord(CargoShippingModel rec) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l.cargoShippingDeleteConfirmTitle,
      message: l.cargoShippingDeleteConfirmMessage(rec.cargoShippingCode, rec.importFileCode ?? ''),
      confirmLabel: l.cargoShippingConfirmDeleteBtn,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.delete_outline,
    );
    if (confirm) {
      await ref.read(cargoShippingProvider.notifier).softDeleteRecord(rec.cargoShippingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.cargoShippingDeleteSuccess(rec.cargoShippingCode), severity: AppSeverity.danger),
        );
      }
    }
  }

  Future<void> _toggleRecordActive(CargoShippingModel rec) async {
    final l = context.l10n;
    if (rec.isActive) {
      await _confirmDeleteRecord(rec);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      final snack = AppTheme.snackBar(
        context,
        l.cargoShippingRestoreSuccess(rec.cargoShippingCode),
        severity: AppSeverity.success,
      );
      await ref.read(cargoShippingProvider.notifier).restoreRecord(rec.cargoShippingId);
      if (mounted) {
        messenger.showSnackBar(snack);
      }
    }
  }

  List<CargoShippingModel> _filterRecords(List<CargoShippingModel> list) {
    return list.where((item) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchCode = item.cargoShippingCode.toLowerCase().contains(query);
        final matchFile = (item.importFileCode ?? '').toLowerCase().contains(query);
        final matchCompany = (item.companyName ?? '').toLowerCase().contains(query);
        final matchContainer = item.containersLoadingData.any(
          (c) => c.containerNo.toLowerCase().contains(query) || c.sealNo.toLowerCase().contains(query),
        );
        if (!matchCode && !matchFile && !matchCompany && !matchContainer) return false;
      }

      if (_registryStatusFilter != 'All' && item.status != _registryStatusFilter) return false;

      final hasBreach = item.containersLoadingData.any((c) => c.isSlaBreached) || (item.lclTrackingData?.isSlaBreached ?? false);
      if (_registrySlaFilter == 'Breached' && !hasBreach) return false;
      if (_registrySlaFilter == 'OnTime' && hasBreach) return false;

      if (_registryActiveFilter == 'Active' && !item.isActive) return false;
      if (_registryActiveFilter == 'Deleted' && item.isActive) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(cargoShippingProvider);
    final l = context.l10n;
    final allRecords = recordsAsync.valueOrNull ?? const <CargoShippingModel>[];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MasterDataToolbarWidget(
              moduleEndpoint: 'cargo-shipping',
              title: 'Cargo_Shipping_Registry',
              onRefreshNeeded: widget.onRefreshNeeded,
            ),
            const SizedBox(height: 12),
            CargoShippingRegistryToolbar(
              allRecords: allRecords,
              onCreateNewRecord: widget.onCreateNewRecord,
              onSearchAndClone: () => CargoShippingCloneDialogHelper.openSearchAndCloneDialog(
                context: context,
                records: allRecords,
                onSelectRecord: (selected) => CargoShippingCloneDialogHelper.showCloneReviewDialog(
                  context: context,
                  rec: selected,
                  onCloneRecordToForm: widget.onCloneRecordToForm,
                ),
              ),
              onCopyTableTsv: () => CargoShippingRegistryExportHelper.copyTableTsv(
                context: context,
                records: allRecords,
                l: l,
              ),
              onExportExcel: () => CargoShippingRegistryExportHelper.exportExcel(
                context: context,
                records: allRecords,
                l: l,
              ),
              onExportPdf: () => CargoShippingRegistryExportHelper.exportPdf(
                context: context,
                records: allRecords,
                l: l,
              ),
              searchController: _searchController,
              statusFilter: _registryStatusFilter,
              onStatusFilterChanged: (v) => setState(() => _registryStatusFilter = v ?? 'All'),
              slaFilter: _registrySlaFilter,
              onSlaFilterChanged: (v) => setState(() => _registrySlaFilter = v ?? 'All'),
              activeFilter: _registryActiveFilter,
              onActiveFilterChanged: (v) => setState(() => _registryActiveFilter = v ?? 'Active'),
            ),
            const SizedBox(height: 12),
            recordsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppLoadingState(),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppErrorState(
                  message: '${context.l10n.error}: $err',
                  onRetry: widget.onRefreshNeeded,
                ),
              ),
              data: (list) {
                final filtered = _filterRecords(list);

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: AppEmptyState(
                      message: context.l10n.cargoShippingNoMatchingRecords,
                      icon: Icons.folder_open,
                      actionLabel: context.l10n.cargoShippingCreateNewRecord,
                      onAction: widget.onCreateNewRecord,
                    ),
                  );
                }

                final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
                final importFilesMap = {for (final f in importFiles) f.importFileId: f};
                final shippingNotifier = ref.read(cargoShippingProvider.notifier);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: AppTheme.cardDecorationOf(context),
                      clipBehavior: Clip.antiAlias,
                      child: EnterpriseDataTable<CargoShippingModel>(
                        storageKey: 'cargo_shipping_enterprise_table',
                        data: filtered,
                        minWidth: 1400,
                        showHeaderToolbar: false,
                        showPagination: false,
                        columns: buildCargoShippingColumns(
                          context: context,
                          l: l,
                          importFilesMap: importFilesMap,
                          onEditRecord: widget.onEditRecord,
                          onCloneRecord: (rec) => CargoShippingCloneDialogHelper.showCloneReviewDialog(
                            context: context,
                            rec: rec,
                            onCloneRecordToForm: widget.onCloneRecordToForm,
                          ),
                          onToggleActive: _toggleRecordActive,
                          onCopyRow: (rec) => CargoShippingRegistryExportHelper.copyRowTsv(
                            context: context,
                            rec: rec,
                            l: l,
                          ),
                        ),
                      ),
                    ),
                    ListLoadMoreFooter(
                      loaded: list.length,
                      total: shippingNotifier.totalCount,
                      hasMore: shippingNotifier.hasMore,
                      onLoadMore: shippingNotifier.loadMore,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
