import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance_quotations/widgets/smart_clearance_extractor_dialog.dart';
import '../../providers/customs_consultation_provider.dart';
import '../price_list_form_dialog.dart';

class BrokerPriceListsView extends ConsumerStatefulWidget {
  final List<dynamic> brokersList;

  const BrokerPriceListsView({
    super.key,
    required this.brokersList,
  });

  @override
  ConsumerState<BrokerPriceListsView> createState() => _BrokerPriceListsViewState();
}

class _BrokerPriceListsViewState extends ConsumerState<BrokerPriceListsView> {
  int? _selectedMgmtBrokerId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final priceListsAsync = ref.watch(brokerPriceListsProvider);

    return priceListsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('❌ Error: $e')),
      data: (priceLists) {
        final filteredLists = priceLists.where((pl) {
          if (_selectedMgmtBrokerId != null && pl.brokerId != _selectedMgmtBrokerId) {
            return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // Filter Bar
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: SearchableDropdownField<int?>(
                        value: _selectedMgmtBrokerId,
                        labelText: l.filterByBroker,
                        searchHintText: l.searchBrokerHint,
                        items: [
                          SearchableDropdownItem(value: null, label: l.allBrokers),
                          ...widget.brokersList.map((b) => SearchableDropdownItem<int?>(
                                value: b.providerId,
                                label: b.partnerName,
                              )),
                        ],
                        onChanged: (v) => setState(() => _selectedMgmtBrokerId = v),
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      label: '🤖 ${l.smartClearanceQuoteExtractor}',
                      icon: Icons.auto_awesome,
                      variant: AppButtonVariant.primary,
                      onPressed: () => showSmartClearanceExtractorDialog(context, ref),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: l.createBrokerPriceListBtn,
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      onPressed: () => showPriceListFormDialog(
                        context,
                        ref,
                        brokersList: widget.brokersList,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Price Lists Table / Grid
            Expanded(
              child: filteredLists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 64, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            l.noBrokerPriceListsFound,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: l.addPriceListNowBtn,
                            icon: Icons.add,
                            variant: AppButtonVariant.primary,
                            onPressed: () => showPriceListFormDialog(
                              context,
                              ref,
                              brokersList: widget.brokersList,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredLists.length,
                      itemBuilder: (ctx, idx) {
                        final pl = filteredLists[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.price_change, color: AppTheme.cobalt),
                            ),
                            title: Row(
                              children: [
                                Text(pl.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pl.isActive ? AppTheme.emeraldBorder : AppTheme.crimsonBorder,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pl.isActive ? l.activePriceListStatus : l.archivedPriceListStatus,
                                    style: TextStyle(
                                      color: pl.isActive ? AppTheme.wcagEmerald : AppTheme.crimson,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (pl.clonedFromCode != null && pl.clonedFromCode!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      l.clonedFromBadge(pl.clonedFromCode!),
                                      style: const TextStyle(
                                        color: AppTheme.cobalt,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                AppButton(
                                  label: l.editPricesAndItemsBtn,
                                  icon: Icons.edit,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  onPressed: () => showPriceListFormDialog(
                                    context,
                                    ref,
                                    existingPriceList: pl,
                                    brokersList: widget.brokersList,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 20),
                                  tooltip: l.clonePriceListActionTooltip,
                                  onPressed: () {
                                    CloneEntityReviewDialog.show(
                                      context,
                                      entityType: l.clonePriceListDialogTitle,
                                      sourceCode: pl.priceListCode,
                                      suggestedNewCode: '${pl.priceListCode}-CLONE',
                                      sourceTitle: pl.title,
                                      copiedFieldsSummary: {
                                        context.l10n.operationalTsvHeaderBroker: pl.brokerName,
                                        context.l10n.ccTargetPort: pl.portName ?? '-',
                                        context.l10n.ccItemsCount: '${pl.items.length}',
                                        context.l10n.ccEffectiveFrom: pl.effectiveFrom,
                                      },
                                      mandatorilyResetFields: [
                                        l.cloneFieldStatusDraftBadge,
                                        context.l10n.ccIncrementVersionNumber,
                                        context.l10n.ccGenerateUniqueNewReferenceCode,
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
                                        final sm = ScaffoldMessenger.of(context);
                                        final snack = AppTheme.snackBar(
                                          context,
                                          l.clonedSuccessfullyToast(newCode),
                                          severity: AppSeverity.success,
                                        );
                                        await ref.read(brokerPriceListsProvider.notifier).clonePriceList(
                                          pl.priceListId,
                                          {
                                            'new_price_list_code': newCode,
                                            'new_title': newTitle,
                                            'copy_items': copyLineItems,
                                            if (notes != null) 'notes': notes,
                                          },
                                        );
                                        if (mounted) {
                                          sm.showSnackBar(snack);
                                        }
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                                  tooltip: l.archivePriceListTooltip,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l.confirmArchivePriceListTitle),
                                        content: Text(l.confirmArchivePriceListMsg(pl.title)),
                                        actions: [
                                          AppButton(
                                            label: l.cancel,
                                            variant: AppButtonVariant.secondary,
                                            size: AppButtonSize.small,
                                            onPressed: () => Navigator.pop(ctx, false),
                                          ),
                                          AppButton(
                                            label: l.archiveBtn,
                                            variant: AppButtonVariant.danger,
                                            onPressed: () => Navigator.pop(ctx, true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(brokerPriceListsProvider.notifier).softDeletePriceList(pl.priceListId);
                                    }
                                  },
                                ),
                              ],
                            ),
                            subtitle: Text('${l.responsibleCustomsBroker}: ${pl.brokerName} | ${l.targetPortField}: ${pl.portName ?? "-"} | ${pl.effectiveFrom} | ${pl.items.length}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pl.notes != null && pl.notes!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.orangeLight,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppTheme.orange),
                                        ),
                                        child: Text('📝 ${l.priceListNotesHeader} ${pl.notes}', style: const TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Table(
                                      border: TableBorder.all(color: AppTheme.cloudWhite),
                                      columnWidths: const {
                                        0: FlexColumnWidth(3.0),
                                        1: FlexColumnWidth(2.0),
                                        2: FlexColumnWidth(1.2),
                                        3: FlexColumnWidth(1.5),
                                        4: FlexColumnWidth(2.0),
                                      },
                                      children: [
                                        TableRow(
                                          decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                                          children: [
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseItemNameCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseCategoryCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.expenseUnitCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.standardPriceCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                            Padding(padding: const EdgeInsets.all(6), child: Text(l.priceRangeAndNotesCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                          ],
                                        ),
                                        ...pl.items.map((itm) => TableRow(
                                              children: [
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.expenseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.category.split('(').first.trim(), style: const TextStyle(fontSize: 10))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(itm.unitType, style: const TextStyle(fontSize: 10))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text('${itm.standardPrice.toStringAsFixed(2)} ${itm.currency}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11))),
                                                Padding(
                                                  padding: const EdgeInsets.all(6),
                                                  child: Text(
                                                    itm.minPrice != null && itm.maxPrice != null
                                                        ? '${itm.minPrice!.toStringAsFixed(0)} - ${itm.maxPrice!.toStringAsFixed(0)} ${itm.currency}'
                                                        : (itm.notes ?? '-'),
                                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                                  ),
                                                ),
                                              ],
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
