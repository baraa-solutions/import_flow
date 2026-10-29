import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../models/item_price_trends_model.dart';
import '../models/master_item_model.dart';

/// 1️⃣ Price Trends KPI Cards (MD-ITEM-001 / Session 3)
/// Executive procurement KPI metrics: Lowest Price, Highest Price,
/// Average Landed Cost Markup, and Price Stability Index.
class PriceTrendsKpiCards extends ConsumerWidget {
  final ItemPriceTrendsModel trends;
  final MasterItemModel? item;

  const PriceTrendsKpiCards({
    super.key,
    required this.trends,
    this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Currency of deals or default to USD
    final currency = trends.history.isNotEmpty
        ? trends.history.first.currency
        : 'USD';

    // Calculate Price Stability Index and Volatility
    final avgPrice = trends.averageUnitPriceFx;
    final minPrice = trends.minUnitPriceFx;
    final maxPrice = trends.maxUnitPriceFx;
    final spread = maxPrice - minPrice;
    final variancePct = avgPrice > 0 ? (spread / avgPrice) * 100 : 0.0;
    final stabilityScore = (100.0 - variancePct).clamp(0.0, 100.0);

    String stabilityLabel;
    Color stabilityColor;
    IconData stabilityIcon;

    if (variancePct <= 8.0) {
      stabilityLabel = 'مستقر ممتاز';
      stabilityColor = AppTheme.flatEmerald;
      stabilityIcon = Icons.verified_rounded;
    } else if (variancePct <= 20.0) {
      stabilityLabel = 'تذبذب معتدل';
      stabilityColor = AppTheme.flatOrange;
      stabilityIcon = Icons.change_circle_outlined;
    } else {
      stabilityLabel = 'تذبذب مرتفع';
      stabilityColor = AppTheme.flatCrimson;
      stabilityIcon = Icons.warning_amber_rounded;
    }

    final avgMarkup = trends.averageMarkupPercent ?? 0.0;
    final markupMultiplier = 1.0 + (avgMarkup / 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1020;
        final cardWidth = isWide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth >= 560 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth);

        final cards = [
          // Card 1: Lowest Purchase Price
          _buildKpiCard(
            context: context,
            density: density,
            isDark: isDark,
            width: cardWidth,
            title: 'أقل سعر شراء',
            value: '${minPrice.toStringAsFixed(2)} $currency',
            subtitle: 'الصفقة الأوفر في السجل',
            icon: Icons.trending_down_rounded,
            iconColor: AppTheme.flatEmerald,
            badgeText: 'أفضل سعر',
            badgeColor: AppTheme.flatEmerald,
          ),

          // Card 2: Highest Purchase Price
          _buildKpiCard(
            context: context,
            density: density,
            isDark: isDark,
            width: cardWidth,
            title: 'أعلى سعر شراء',
            value: '${maxPrice.toStringAsFixed(2)} $currency',
            subtitle: 'فارق السعر: +${spread.toStringAsFixed(2)} (${variancePct.toStringAsFixed(1)}%)',
            icon: Icons.trending_up_rounded,
            iconColor: AppTheme.flatCrimson,
            badgeText: 'سقف التكلفة',
            badgeColor: AppTheme.flatCrimson,
          ),

          // Card 3: Average Landed Cost Markup
          _buildKpiCard(
            context: context,
            density: density,
            isDark: isDark,
            width: cardWidth,
            title: 'متوسط معامل الإضافة',
            value: '+${avgMarkup.toStringAsFixed(1)}% (${markupMultiplier.toStringAsFixed(2)}x)',
            subtitle: trends.averageLandedCostEgp != null
                ? 'متوسط الوصول: ${trends.averageLandedCostEgp!.toStringAsFixed(2)} ج.م'
                : 'جمارك، شحن، أرضيات ومصاريف وصول',
            icon: Icons.account_balance_rounded,
            iconColor: AppTheme.flatCobalt,
            badgeText: 'تكلفة الوصول',
            badgeColor: AppTheme.flatCobalt,
          ),

          // Card 4: Price Stability Index
          _buildKpiCard(
            context: context,
            density: density,
            isDark: isDark,
            width: cardWidth,
            title: 'مؤشر استقرار السعر',
            value: '${stabilityScore.toStringAsFixed(0)}% استقرار',
            subtitle: '$stabilityLabel (${trends.totalPurchasesCount} صفقات مسجلة)',
            icon: stabilityIcon,
            iconColor: stabilityColor,
            badgeText: stabilityLabel,
            badgeColor: stabilityColor,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required DisplayDensityMode density,
    required bool isDark,
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: density.tableCellSecondaryFontSize,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: density.headerTitleFontSize,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
