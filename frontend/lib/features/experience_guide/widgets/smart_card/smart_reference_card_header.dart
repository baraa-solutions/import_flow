import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/smart_reference_card_model.dart';

class SmartReferenceCardHeader extends StatelessWidget {
  final SmartReferenceCardModel card;
  final VoidCallback onRefresh;
  final VoidCallback onCopy;
  final VoidCallback onManageGuide;
  final VoidCallback onAddGuideline;
  final bool isDark;
  final bool isArabic;

  const SmartReferenceCardHeader({
    super.key,
    required this.card,
    required this.onRefresh,
    required this.onCopy,
    required this.onManageGuide,
    required this.onAddGuideline,
    required this.isDark,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.flatCobalt, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.smartReferenceCardTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${card.importFileCode} ${card.customFileNumber != null && card.customFileNumber!.isNotEmpty ? "• ${card.customFileNumber}" : ""}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppTheme.flatCobalt),
              tooltip: isArabic ? 'تحديث بيانات الشحنة والمرجع' : 'Refresh Reference Card',
              onPressed: onRefresh,
            ),
            IconButton(
              icon: Icon(Icons.copy_all, size: 20, color: isDark ? AppTheme.darkTextPrimary : AppTheme.flatCharcoal),
              tooltip: l10n.copyReferenceCardTooltip,
              onPressed: onCopy,
            ),
            IconButton(
              icon: const Icon(Icons.library_books_outlined, size: 20, color: AppTheme.flatCobalt),
              tooltip: l10n.manageGuideEntriesBtn,
              onPressed: onManageGuide,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.addGuideEntryBtn, style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.flatCharcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: onAddGuideline,
            ),
          ],
        ),
      ],
    );
  }
}
