import 'package:flutter/material.dart';
import '../../../features/cargox/models/export_configs.dart';
import '../../theme/app_theme.dart';

/// Reusable UI component for Dimensions 1 & 2 of the Document Export Engine (Task K).
///
/// Combines:
/// - Dimension 1: File Packaging (Single Sheet ↔ ZIP Archive per Invoice)
/// - Dimension 2: Content Detail (Consolidated ↔ Detailed)
///
/// Used identically across Commercial Invoice and Customs Packing List panels.
class PackagingDetailToggle extends StatelessWidget {
  final FilePackagingMode packaging;
  final ContentDetailMode detail;
  final ValueChanged<FilePackagingMode> onPackagingChanged;
  final ValueChanged<ContentDetailMode> onDetailChanged;
  final Color activeColor;

  const PackagingDetailToggle({
    super.key,
    required this.packaging,
    required this.detail,
    required this.onPackagingChanged,
    required this.onDetailChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Dimension 1: File Packaging ──────────────────────────────────────
        Text(
          isAr ? '١. نمط حفظ وتغليف الملف:' : '1. File Packaging Mode:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildSelectableChip(
                context: context,
                icon: Icons.description_outlined,
                label: isAr ? FilePackagingMode.singleFile.labelAr : FilePackagingMode.singleFile.labelEn,
                tooltip: isAr ? FilePackagingMode.singleFile.descAr : FilePackagingMode.singleFile.descEn,
                isSelected: packaging == FilePackagingMode.singleFile,
                onTap: () => onPackagingChanged(FilePackagingMode.singleFile),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectableChip(
                context: context,
                icon: Icons.archive_outlined,
                label: isAr ? FilePackagingMode.zipPerInvoice.labelAr : FilePackagingMode.zipPerInvoice.labelEn,
                tooltip: isAr ? FilePackagingMode.zipPerInvoice.descAr : FilePackagingMode.zipPerInvoice.descEn,
                isSelected: packaging == FilePackagingMode.zipPerInvoice,
                onTap: () => onPackagingChanged(FilePackagingMode.zipPerInvoice),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Dimension 2: Content Detail ──────────────────────────────────────
        Text(
          isAr ? '٢. درجة تفصيل البيانات:' : '2. Content Detail Level:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildSelectableChip(
                context: context,
                icon: Icons.compress_rounded,
                label: isAr ? ContentDetailMode.consolidated.labelAr : ContentDetailMode.consolidated.labelEn,
                tooltip: isAr ? ContentDetailMode.consolidated.descAr : ContentDetailMode.consolidated.descEn,
                isSelected: detail == ContentDetailMode.consolidated,
                onTap: () => onDetailChanged(ContentDetailMode.consolidated),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectableChip(
                context: context,
                icon: Icons.format_list_numbered_rounded,
                label: isAr ? ContentDetailMode.detailed.labelAr : ContentDetailMode.detailed.labelEn,
                tooltip: isAr ? ContentDetailMode.detailed.descAr : ContentDetailMode.detailed.descEn,
                isSelected: detail == ContentDetailMode.detailed,
                onTap: () => onDetailChanged(ContentDetailMode.detailed),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final selectedBorderColor = activeColor;
    final unselectedBorderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade300;
    final selectedBgColor = activeColor.withValues(alpha: isDark ? 0.22 : 0.10);
    final unselectedBgColor = isDark ? AppTheme.darkCardBackground : Colors.white;
    final textColor = isSelected
        ? activeColor
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBgColor : unselectedBgColor,
            border: Border.all(
              color: isSelected ? selectedBorderColor : unselectedBorderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
