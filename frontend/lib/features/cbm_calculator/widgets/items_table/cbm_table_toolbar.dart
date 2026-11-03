import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Toolbar header card for CbmItemsTable
class CbmTableToolbar extends StatelessWidget {
  final String shipmentMode;
  final int? activeSessionId;
  final ValueChanged<String> onShipmentModeChanged;
  final VoidCallback onAddPackageLine;
  final VoidCallback onSaveCalculation;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyPackagesTsv;
  final VoidCallback onCopyStudyReport;

  const CbmTableToolbar({
    super.key,
    required this.shipmentMode,
    required this.activeSessionId,
    required this.onShipmentModeChanged,
    required this.onAddPackageLine,
    required this.onSaveCalculation,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyPackagesTsv,
    required this.onCopyStudyReport,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_list_bulleted, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l.packageMeasurementsTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Shipment Mode Selector (Air vs Sea vs Road)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: Text(l.airFreightMode),
                        selected: shipmentMode == 'air',
                        selectedColor: AppTheme.cobalt,
                        labelStyle: TextStyle(
                          color: shipmentMode == 'air' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => onShipmentModeChanged('air'),
                      ),
                      ChoiceChip(
                        label: Text(l.seaFreightMode),
                        selected: shipmentMode == 'sea',
                        selectedColor: AppTheme.emerald,
                        labelStyle: TextStyle(
                          color: shipmentMode == 'sea' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => onShipmentModeChanged('sea'),
                      ),
                      ChoiceChip(
                        label: Text(isArabic ? 'شحن بري (Road/LDM)' : 'Road Freight (LDM)'),
                        selected: shipmentMode == 'road',
                        selectedColor: AppTheme.wcagOrange,
                        labelStyle: TextStyle(
                          color: shipmentMode == 'road' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => onShipmentModeChanged('road'),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: l.addPackageLine,
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
                  onPressed: onAddPackageLine,
                ),
                AppButton(
                  label: activeSessionId != null ? l.saveChanges : l.saveCalculationSession,
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.success,
                  onPressed: onSaveCalculation,
                ),
                AppButton(
                  label: isArabic ? 'تصدير إكسيل' : 'Export Excel',
                  icon: Icons.table_chart,
                  variant: AppButtonVariant.success,
                  onPressed: onExportExcel,
                ),
                AppButton(
                  label: isArabic ? 'تصدير PDF' : 'Export PDF',
                  icon: Icons.picture_as_pdf,
                  variant: AppButtonVariant.danger,
                  onPressed: onExportPdf,
                ),
                AppButton(
                  label: isArabic ? 'نسخ الطرود' : 'Copy Packages',
                  icon: Icons.content_copy,
                  variant: AppButtonVariant.secondary,
                  onPressed: onCopyPackagesTsv,
                ),
                AppButton(
                  label: isArabic ? 'نسخ التقرير الفني' : 'Copy Study Report',
                  icon: Icons.assignment_outlined,
                  variant: AppButtonVariant.primary,
                  onPressed: onCopyStudyReport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
