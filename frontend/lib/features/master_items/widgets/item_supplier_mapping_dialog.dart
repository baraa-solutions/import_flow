import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/master_item_model.dart';
import '../providers/master_items_provider.dart';
import 'mapping/add_supplier_mapping_form.dart';
import 'mapping/linked_suppliers_table.dart';
import 'mapping/mapping_dialog_header.dart';

export 'mapping/add_supplier_mapping_form.dart' show kStandardCurrencies, kStandardIncoterms;

/// Dialog for managing Overseas Supplier Linkages and Part Numbers for a Master Item
class ItemSupplierMappingDialog extends ConsumerStatefulWidget {
  final MasterItemModel item;

  const ItemSupplierMappingDialog({
    super.key,
    required this.item,
  });

  /// Static helper to open the dialog
  static Future<void> show(
    BuildContext context, {
    required MasterItemModel item,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ItemSupplierMappingDialog(item: item),
    );
  }

  @override
  ConsumerState<ItemSupplierMappingDialog> createState() => _ItemSupplierMappingDialogState();
}

class _ItemSupplierMappingDialogState extends ConsumerState<ItemSupplierMappingDialog> {
  bool _showAddForm = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkedSuppliersAsync = ref.watch(itemSuppliersProvider(widget.item.itemId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 880,
            maxHeight: 740,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────
              MappingDialogHeader(
                item: widget.item,
                onClose: () => Navigator.of(context).pop(),
              ),

              // ── Body ─────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Linked Suppliers List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business_outlined, size: 18, color: AppTheme.cobalt),
                              const SizedBox(width: 6),
                              const Text(
                                'الموردون المرتبطون بهذا الصنف',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              linkedSuppliersAsync.maybeWhen(
                                data: (list) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${list.length} مورد',
                                    style: const TextStyle(
                                      color: AppTheme.cobalt,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (!_showAddForm)
                            AppButton(
                              label: 'ربط مورد جديد',
                              icon: Icons.add_link_rounded,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              onPressed: () => setState(() => _showAddForm = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Linked Suppliers Table or Empty State
                      LinkedSuppliersTable(linkedSuppliersAsync: linkedSuppliersAsync),
                      const SizedBox(height: 16),

                      // Section 2: Form to Link New Supplier (Toggled)
                      if (_showAddForm)
                        AddSupplierMappingForm(
                          itemId: widget.item.itemId,
                          onCancel: () => setState(() => _showAddForm = false),
                          onSuccess: () => setState(() => _showAddForm = false),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Footer ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'إغلاق',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
