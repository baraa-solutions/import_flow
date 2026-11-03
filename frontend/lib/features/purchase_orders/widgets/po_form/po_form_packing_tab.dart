import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../models/purchase_order_model.dart';
import '../po_form_dialog.dart';
import '../po_reconciliation_warning_dialog.dart';
import 'packing/packing_entries_header.dart';
import 'packing/packing_item_card.dart';
import 'packing/packing_mode_banner.dart';
import 'packing/packing_upload_banner.dart';
import 'packing/pallet_plan_board.dart';

/// Tab 2: Detailed packing list, weight, dimensions, CBM and palletization plan.
class POFormPackingTab extends StatelessWidget {
  final POFormDialogState dialog;

  const POFormPackingTab({super.key, required this.dialog});

  void _handleAutoFill(BuildContext context) {
    if (dialog.dialogItems.isEmpty) return;
    dialog.updateState(() {
      dialog.dialogPackingItems = dialog.dialogItems.asMap().entries.map((e) {
        final item = e.value;
        return PackingListItemModel(
          hsCode: item.hsCode ?? '',
          itemCode: (item.itemCode != null && item.itemCode!.trim().isNotEmpty)
              ? item.itemCode!.trim()
              : 'ITEM-${(e.key + 1).toString().padLeft(3, "0")}',
          mainDescription: item.mainDescription,
          description: item.descriptionAr.isNotEmpty ? item.descriptionAr : item.descriptionEn,
          qtyPcs: item.quantity,
          qtyPkg: (item.quantity > 0 ? (item.quantity / 10).ceilToDouble() : 10.0),
          packageType: 'Carton',
          lengthCm: 50,
          widthCm: 40,
          heightCm: 30,
          netWeightUnitKg: item.netWeightKg > 0 ? item.netWeightKg : 5.0,
          grossWeightUnitKg: item.grossWeightKg > 0 ? item.grossWeightKg : 6.0,
        );
      }).toList();
    });
  }

  void _handleAddEntry() {
    dialog.updateState(() {
      dialog.dialogPackingItems.add(PackingListItemModel(
        hsCode: '',
        itemCode: 'ITEM-${(dialog.dialogPackingItems.length + 1).toString().padLeft(3, "0")}',
        qtyPcs: 10,
        qtyPkg: 1,
        lengthCm: 50,
        widthCm: 40,
        heightCm: 30,
        netWeightUnitKg: 5,
        grossWeightUnitKg: 6,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;
    final ref = dialog.ref;
    final tariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];

    final reconciliation = evaluatePOReconciliation(
      invoiceItems: dialog.dialogItems,
      packingItems: dialog.dialogPackingItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHsCodes = reconciliation.items
        .where((i) => !i.isMatched || i.isMissingInPacking || i.isMissingInInvoice)
        .map((i) => i.hsCode)
        .toSet();

    final cachedPackageTypeItems = kMasterPackageTypes.map((p) {
      final cleanAr = p['name']!.split('(').first.replaceAll(RegExp(r'^[A-Z0-9]+\s*-\s*'), '').trim();
      final cleanEn = p['name']!.split(' - ').last.split('(').first.trim();
      final label = isArabic ? '${p['code']} - $cleanAr' : '${p['code']} - $cleanEn';
      return SearchableDropdownItem<String>(value: p['name']!, label: label);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(top: 8, end: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Smart Packing List Upload Banner
          PackingUploadBanner(dialog: dialog, isArabic: isArabic),

          // Dual-Mode Selection Banner
          PackingModeBanner(dialog: dialog, isArabic: isArabic),

          // Multi-Row Palletization Board
          if (dialog.isDirectVolumeMode)
            PalletPlanBoard(dialog: dialog, isArabic: isArabic, l: l),

          const SizedBox(height: 16),

          // Packing Entries Section Header
          PackingEntriesHeader(
            dialog: dialog,
            l: l,
            onAutoFill: () => _handleAutoFill(context),
            onAddEntry: _handleAddEntry,
          ),
          const SizedBox(height: 8),

          // Packing List Cards
          if (dialog.dialogPackingItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      l.noPackingEntriesYet,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.noPackingEntriesYetDesc,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dialog.dialogPackingItems.length,
              itemBuilder: (context, idx) {
                final p = dialog.dialogPackingItems[idx];
                final isMismatched = p.hsCode.isNotEmpty && mismatchedHsCodes.contains(p.hsCode);

                return PackingItemCard(
                  dialog: dialog,
                  idx: idx,
                  p: p,
                  isMismatched: isMismatched,
                  tariffs: tariffs,
                  cachedPackageTypeItems: cachedPackageTypeItems,
                  isArabic: isArabic,
                  l: l,
                );
              },
            ),
        ],
      ),
    );
  }
}
