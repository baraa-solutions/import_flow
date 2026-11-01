import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../master_items/models/master_item_model.dart';
import '../../../master_items/widgets/master_item_autocomplete_field.dart';

class POLineItemCatalogSection extends StatelessWidget {
  final bool wasAutoFilled;
  final bool isArabic;
  final String initialItemCode;
  final MasterItemModel? selectedMasterItem;
  final ValueChanged<MasterItemModel> onItemSelected;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const POLineItemCatalogSection({
    super.key,
    required this.wasAutoFilled,
    required this.isArabic,
    required this.initialItemCode,
    required this.selectedMasterItem,
    required this.onItemSelected,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: wasAutoFilled
              ? AppTheme.emeraldBorder
              : AppTheme.cobalt.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: wasAutoFilled ? AppTheme.emerald : AppTheme.cobalt,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic
                      ? 'استدعاء الصنف من الكاتالوج المركزي'
                      : 'Fast Catalog Autocomplete & Pre-fill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: wasAutoFilled ? AppTheme.emerald : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (wasAutoFilled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 12, color: AppTheme.emerald),
                      const SizedBox(width: 4),
                      Text(
                        l.masterItemAutoFilled,
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
            ],
          ),
          const SizedBox(height: 8),
          MasterItemAutocompleteField(
            initialValue: initialItemCode,
            selectedItem: selectedMasterItem,
            onItemSelected: onItemSelected,
            onChanged: onChanged,
            onCleared: onCleared,
          ),
        ],
      ),
    );
  }
}
