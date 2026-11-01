import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/purchase_order_model.dart';

class PoMasterPalletPlanSection extends StatelessWidget {
  final List<PalletPlanItemModel> palletPlanItems;
  final VoidCallback? onOpen3dPlanner;

  const PoMasterPalletPlanSection({
    super.key,
    required this.palletPlanItems,
    this.onOpen3dPlanner,
  });

  @override
  Widget build(BuildContext context) {
    if (palletPlanItems.isEmpty) return const SizedBox.shrink();

    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pallet, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                l.masterPalletPlanTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🔢 ${l.totalPalletsMetric}: ${l.palletCountWithUnit(palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount))}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '📐 ${l.palletCbmWithUnit(palletPlanItems.fold<double>(0.0, (sum, p) => sum + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount)).toStringAsFixed(3))}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.wcagOrange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l.simulateAndLoad3d(
                  palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount),
                ),
                icon: Icons.view_in_ar_rounded,
                variant: AppButtonVariant.warning,
                size: AppButtonSize.small,
                onPressed: () => onOpen3dPlanner?.call(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Table(
            border: TableBorder.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletTypeCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletCountCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletDimensionsCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletWeightCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletTotalWeightCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletVolumeCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      l.palletStackingInstructionsCol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : null,
                      ),
                    ),
                  ),
                ],
              ),
              ...palletPlanItems.map((pal) {
                final palCbm = pal.calculatedCbm > 0
                    ? pal.calculatedCbm
                    : (pal.lengthCm * pal.widthCm * pal.heightCm / 1000000.0) * pal.palletCount;
                final palTotalWt = pal.grossWeightPerPalletKg * pal.palletCount;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        pal.palletType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${pal.palletCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${pal.lengthCm.toStringAsFixed(0)} × ${pal.widthCm.toStringAsFixed(0)} × ${pal.heightCm.toStringAsFixed(0)} cm',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${pal.grossWeightPerPalletKg.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${palTotalWt.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${palCbm.toStringAsFixed(3)} m³',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.orange,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        pal.isStackable ? l.stackableOption : l.nonStackableOption,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pal.isStackable
                              ? (isDark ? AppTheme.emerald : AppTheme.wcagEmerald)
                              : AppTheme.wcagOrange,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
