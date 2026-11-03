import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../models/cbm_calculator_model.dart';

class CbmResultsSummaryHeader extends StatelessWidget {
  final List<CBMItemModel> items;
  final String shipmentMode;
  final bool isStackable;

  const CbmResultsSummaryHeader({
    super.key,
    required this.items,
    required this.shipmentMode,
    required this.isStackable,
  });

  Widget _buildResultCardItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  CopyableText(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    CopyableText(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    double totalCbm = 0.0;
    double totalGrossWt = 0.0;
    double totalVolumetricWt = 0.0;
    double totalFloorAreaM2 = 0.0;

    for (var item in items) {
      final lM = item.lengthM;
      final wM = item.widthM;
      final hM = item.heightM;
      final cbm = item.quantity * lM * wM * hM;
      final volWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
      final gross = item.quantity * item.grossWeightPerUnitKg;
      final floor = item.quantity * lM * wM;
      totalFloorAreaM2 += floor;

      totalCbm += cbm;
      totalVolumetricWt += volWt;
      totalGrossWt += gross;
    }

    final chargeableWt = totalGrossWt > totalVolumetricWt ? totalGrossWt : totalVolumetricWt;
    final totalLdm = ContainerRequirementEngine.calculateLdm(floorAreaM2: totalFloorAreaM2);
    final totalChargeableCbm = ContainerRequirementEngine.calculateLclChargeableCbm(
      physicalCbm: totalCbm,
      floorAreaM2: totalFloorAreaM2,
      isStackable: isStackable,
    );
    final totalRevenueTon = ContainerRequirementEngine.calculateOceanRevenueTon(
      chargeableCbm: totalChargeableCbm,
      totalGrossWeightKg: totalGrossWt,
    );

    final dualRec = ContainerRequirementEngine.calculateBoth(totalCbm: totalCbm, totalWeightKg: totalGrossWt);
    final containerRec = isStackable ? dualRec.stackableResult : dualRec.nonStackableResult;
    final modeRec = dualRec.modeRecommendation;

    String recMethod = isArabic ? modeRec.recommendedModeAr : modeRec.recommendedMode;
    String recContainer = isArabic ? modeRec.reasonAr : modeRec.reasonEn;
    if (totalCbm >= 15.0) {
      recContainer = isArabic ? containerRec.recommendationSummary : containerRec.recommendationSummaryEn;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildResultCardItem(
            context,
            l.totalCbmVolumeMetric,
            '${totalCbm.toStringAsFixed(4)} m³',
            Icons.view_in_ar,
            AppTheme.orange,
            subtitle: '${isArabic ? "المساحة الأرضية" : "Floor Area"}: ${totalFloorAreaM2.toStringAsFixed(2)} m²',
          ),
          if (shipmentMode == 'sea') ...[
            _buildResultCardItem(
              context,
              isArabic ? 'طن الإيراد (Revenue Ton)' : 'Revenue Ton (W/M)',
              '${totalRevenueTon.toStringAsFixed(3)} RT',
              Icons.waves,
              AppTheme.cobalt,
              subtitle: totalRevenueTon > totalChargeableCbm
                  ? (isArabic ? 'محاسبة بالوزن الفعلي' : 'Billed by gross weight')
                  : (isArabic ? 'محاسبة بالحجم التكعيبي' : 'Billed by volume'),
            ),
            if (!isStackable && totalChargeableCbm > totalCbm)
              _buildResultCardItem(
                context,
                isArabic ? 'الحجم المحاسبي (فراغ ضائع)' : 'Billed CBM (Loss of Height)',
                '${totalChargeableCbm.toStringAsFixed(3)} m³',
                Icons.vertical_align_top,
                AppTheme.wcagOrange,
                subtitle: '+${(totalChargeableCbm - totalCbm).toStringAsFixed(3)} m³ ${isArabic ? "فراغ رأسي محتسب" : "lost height penalty"}',
              ),
            _buildResultCardItem(
              context,
              l.grossWeightMetric,
              '${totalGrossWt.toStringAsFixed(1)} KG',
              Icons.scale,
              AppTheme.emerald,
              subtitle: '${(totalGrossWt / 1000.0).toStringAsFixed(3)} ${isArabic ? "طن متري" : "Metric Ton"}',
            ),
          ] else if (shipmentMode == 'road') ...[
            _buildResultCardItem(
              context,
              isArabic ? 'أمتار التحميل (LDM)' : 'Loading Meters (LDM)',
              '${totalLdm.toStringAsFixed(2)} LDM',
              Icons.local_shipping,
              AppTheme.emerald,
              subtitle: '${(totalLdm / kStandardTrailerMaxLdm * 100).toStringAsFixed(1)}% ${isArabic ? "من تريلا 13.6م" : "of 13.6m trailer"}',
            ),
            _buildResultCardItem(
              context,
              isArabic ? 'المساحة الأرضية' : 'Floor Footprint',
              '${totalFloorAreaM2.toStringAsFixed(2)} m²',
              Icons.square_foot,
              AppTheme.cobalt,
              subtitle: isArabic ? 'عرض التريلا القياسي 2.40م' : 'Based on 2.40m trailer width',
            ),
            _buildResultCardItem(
              context,
              l.grossWeightMetric,
              '${totalGrossWt.toStringAsFixed(1)} KG',
              Icons.scale,
              AppTheme.orange,
            ),
          ],
          if (shipmentMode == 'air') ...[
            _buildResultCardItem(
              context,
              l.airChargeableWtMetric,
              '${chargeableWt.toStringAsFixed(2)} KG',
              Icons.airplanemode_active,
              AppTheme.cobalt,
              subtitle: '${l.volumetricWeight}: ${totalVolumetricWt.toStringAsFixed(2)} kg',
            ),
            _buildResultCardItem(
              context,
              l.grossWeightMetric,
              '${totalGrossWt.toStringAsFixed(2)} KG',
              Icons.scale,
              AppTheme.emerald,
            ),
          ],
          _buildResultCardItem(
            context,
            l.recommendedShippingMetric,
            recMethod,
            Icons.directions_boat,
            modeRec.isAirSuggested ? AppTheme.cobalt : (modeRec.isLclSuggested ? AppTheme.wcagOrange : AppTheme.cobalt),
            subtitle: recContainer,
          ),
        ];

        if (constraints.maxWidth > 950) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: c))).toList(),
          );
        } else if (constraints.maxWidth > 550) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((c) => SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: c,
                    ))
                .toList(),
          );
        } else {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards
                .map((c) => SizedBox(
                      width: constraints.maxWidth,
                      child: c,
                    ))
                .toList(),
          );
        }
      },
    );
  }
}
