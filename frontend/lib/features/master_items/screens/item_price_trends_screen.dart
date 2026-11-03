import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../models/item_price_history_model.dart';
import '../models/item_price_trends_model.dart';
import '../models/master_item_model.dart';
import '../providers/item_price_trends_provider.dart';
import '../providers/master_items_provider.dart';
import '../widgets/deal_breakdown_drawer.dart';
import '../widgets/master_items_filter_bar.dart';
import '../widgets/price_history_timeline_table.dart';
import '../widgets/price_trends_kpi_cards.dart';
import '../widgets/supplier_comparison_radar_card.dart';

/// 3️⃣ Price Trends Radar & Deal Comparison Screen (Type C Dashboard Screen)
/// Purpose: Executive analytical workbench for Procurement Managers to compare
/// item prices across 10+ deals, evaluate customs/landed markup, and benchmark suppliers.
class ItemPriceTrendsScreen extends ConsumerStatefulWidget {
  final int? initialItemId;

  const ItemPriceTrendsScreen({
    super.key,
    this.initialItemId,
  });

  @override
  ConsumerState<ItemPriceTrendsScreen> createState() =>
      _ItemPriceTrendsScreenState();
}

class _ItemPriceTrendsScreenState extends ConsumerState<ItemPriceTrendsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ItemPriceHistoryModel? _selectedDealForBreakdown;

  @override
  void initState() {
    super.initState();
    if (widget.initialItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMasterItemIdProvider.notifier).state =
            widget.initialItemId;
      });
    }
  }

  void _openBreakdown(ItemPriceHistoryModel deal) {
    setState(() {
      _selectedDealForBreakdown = deal;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _copyTechnicalComparisonReport({
    required MasterItemModel item,
    required ItemPriceTrendsModel trends,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final formattedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    buffer.writeln('# 📊 التقرير الفني لتحليل اتجاه الأسعار ومقارنة الصفقات');
    buffer.writeln('**تاريخ التقرير:** $formattedDate | **نظام ImportFlow ERP**');
    buffer.writeln('---');

    // 1. Item Specifications
    buffer.writeln('## 1. مواصفات الصنف والبند الجمركي');
    buffer.writeln('- **كود الصنف الداخلي:** `${item.itemCode}`');
    buffer.writeln('- **الوصف باللغة العربية:** ${item.descriptionAr}');
    if (item.descriptionEn != null && item.descriptionEn!.isNotEmpty) {
      buffer.writeln('- **الوصف باللغة الإنجليزية:** ${item.descriptionEn}');
    }
    buffer.writeln('- **البند الجمركي (HS Code):** ${item.hsCode ?? 'غير محدد'}');
    buffer.writeln(
        '- **الضريبة الجمركية:** ${item.lastCustomsDutyPct?.toStringAsFixed(1) ?? '0.0'}%');
    buffer.writeln(
        '- **ضريبة القيمة المضافة:** ${item.lastVatPct?.toStringAsFixed(1) ?? '14.0'}%');
    buffer.writeln('- **وحدة القياس الافتراضية:** ${item.defaultUom}');
    buffer.writeln(
        '- **الأبعاد والوزن:** ${item.cbmPerUnit} CBM/الوحدة | ${item.grossWeightKg} كجم قائم');
    buffer.writeln('---');

    // 2. Executive KPIs
    final avgPrice = trends.averageUnitPriceFx;
    final minPrice = trends.minUnitPriceFx;
    final maxPrice = trends.maxUnitPriceFx;
    final spread = maxPrice - minPrice;
    final variancePct = avgPrice > 0 ? (spread / avgPrice) * 100 : 0.0;
    final stabilityScore = (100.0 - variancePct).clamp(0.0, 100.0);
    final currency =
        trends.history.isNotEmpty ? trends.history.first.currency : 'USD';
    final avgMarkup = trends.averageMarkupPercent ?? 0.0;
    final markupMultiplier = 1.0 + (avgMarkup / 100.0);

    buffer.writeln('## 2. مؤشرات الأداء السعري والتكلفة (KPIs)');
    buffer.writeln(
        '- **أقل سعر شراء مسجل:** ${minPrice.toStringAsFixed(2)} $currency');
    buffer.writeln(
        '- **أعلى سعر شراء مسجل:** ${maxPrice.toStringAsFixed(2)} $currency');
    buffer.writeln(
        '- **متوسط سعر الشراء:** ${avgPrice.toStringAsFixed(2)} $currency');
    buffer.writeln(
        '- **المدى السعري والتذبذب:** ${spread.toStringAsFixed(2)} $currency (${variancePct.toStringAsFixed(1)}%)');
    buffer.writeln(
        '- **مؤشر استقرار السعر:** ${stabilityScore.toStringAsFixed(0)}% (${variancePct <= 8 ? 'مستقر ممتاز' : variancePct <= 20 ? 'تذبذب معتدل' : 'تذبذب مرتفع'})');
    buffer.writeln(
        '- **متوسط نسبة الإضافة الجمركية والتكلفة:** +${avgMarkup.toStringAsFixed(1)}% (معامل وصول ${markupMultiplier.toStringAsFixed(2)}x)');
    if (trends.averageLandedCostEgp != null) {
      buffer.writeln(
          '- **متوسط تكلفة الوصول الفعلية:** ${trends.averageLandedCostEgp!.toStringAsFixed(2)} ج.م');
    }
    buffer.writeln(
        '- **إجمالي الصفقات التي خضعت للدراسة:** ${trends.totalPurchasesCount} صفقات مسجلة');
    buffer.writeln('---');

    // 3. Historical Deals Matrix
    buffer.writeln('## 3. سجل الصفقات التاريخية وتكلفة الوصول');
    buffer.writeln(
        '| # | التاريخ | أمر الشراء | ملف الاستيراد | المورد | الكمية | السعر أجنبي | سعر الصرف | السعر (ج.م) | تكلفة الوصول (ج.م) | الإضافة % |');
    buffer.writeln(
        '|---|---|---|---|---|---|---|---|---|---|---|');

    for (var i = 0; i < trends.history.length; i++) {
      final h = trends.history[i];
      buffer.writeln(
          '| ${i + 1} | ${h.poDate ?? '-'} | ${h.poNumber ?? '-'} | ${h.importFileCode ?? '-'} | ${h.supplierName ?? '-'} | ${h.quantity?.toStringAsFixed(0) ?? '-'} | ${h.unitPriceFx.toStringAsFixed(2)} ${h.currency} | ${h.exchangeRate.toStringAsFixed(2)} | ${h.unitPriceEgp?.toStringAsFixed(2) ?? '-'} | ${h.landedCostEgp?.toStringAsFixed(2) ?? '-'} | ${h.landedCostMarkup != null ? '+${h.landedCostMarkup!.toStringAsFixed(1)}%' : '-'} |');
    }
    buffer.writeln('---');

    // 4. Recommendations
    buffer.writeln('## 4. التوصية الاستراتيجية لمدير الشراء');
    if (variancePct <= 8.0) {
      buffer.writeln(
          '✅ يتميز الصنف باستقرار سعري عالٍ عبر الصفقات السابقة، مع معامل إضافة جمركي مستقر بمعدل +${avgMarkup.toStringAsFixed(1)}%. يُوصى بالاعتماد على أسعار العقود طويلة الأجل.');
    } else {
      buffer.writeln(
          '⚠️ يُظهر الصنف تبايناً سعرياً بنسبة ${variancePct.toStringAsFixed(1)}% بين أقل سعر (${minPrice.toStringAsFixed(2)} $currency) وأعلى سعر (${maxPrice.toStringAsFixed(2)} $currency). يُوصى بتوحيد التفاوض واستهداف عروض الموردين الأفضل سعراً مع مراجعة تكاليف الشحن والأرضيات.');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: 'تم نسخ التقرير الفني للمقارنة إلى الحافظة بنجاح',
    );
  }

  @override
  Widget build(BuildContext context) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final itemsAsync = ref.watch(masterItemsProvider);
    final selectedItemId = ref.watch(selectedMasterItemIdProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: _selectedDealForBreakdown != null
          ? Drawer(
              width: 500,
              child: Consumer(
                builder: (context, ref, _) {
                  final items = itemsAsync.valueOrNull?.items ?? [];
                  final activeItem = items.firstWhere(
                    (i) => i.itemId == selectedItemId,
                    orElse: () => items.isNotEmpty ? items.first : _dummyItem,
                  );
                  return DealBreakdownDrawer(
                    deal: _selectedDealForBreakdown!,
                    item: activeItem,
                    onClose: () => Navigator.of(context).pop(),
                  );
                },
              ),
            )
          : null,
      appBar: PageHeader(
        title: 'رادار تحليل اتجاه الأسعار ومقارنة الصفقات',
        icon: Icons.query_stats_rounded,
        iconColor: AppTheme.cobalt,
        actions: [
          // Prominent Button: Copy Technical Comparison Report
          Consumer(
            builder: (context, ref, _) {
              final items = itemsAsync.valueOrNull?.items ?? [];
              final effectiveId = selectedItemId ??
                  (items.isNotEmpty ? items.first.itemId : null);

              final trendsAsync = effectiveId != null
                  ? ref.watch(itemPriceTrendsProvider(effectiveId))
                  : null;

              final trends = trendsAsync?.valueOrNull;
              final selectedItem = effectiveId != null
                  ? items.firstWhere(
                      (i) => i.itemId == effectiveId,
                      orElse: () => items.first,
                    )
                  : null;

              return AppButton(
                label: 'نسخ التقرير الفني للمقارنة',
                icon: Icons.copy_all_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: (trends != null && selectedItem != null)
                    ? () => _copyTechnicalComparisonReport(
                          item: selectedItem,
                          trends: trends,
                        )
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),

          // Live Refresh Button
          IconButton(
            icon: Icon(Icons.refresh,
                color: Colors.white, size: density.buttonIconSize + 2),
            tooltip: 'تحديث فوري للرادار',
            onPressed: () {
              ref.invalidate(masterItemsProvider);
              if (selectedItemId != null) {
                ref.invalidate(itemPriceTrendsProvider(selectedItemId));
                ref.invalidate(itemSuppliersProvider(selectedItemId));
              }
            },
          ),
          const SizedBox(width: 6),

          // Back to Dashboard (Always Last)
          const BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: itemsAsync.when(
          loading: () => const Center(
            child: AppLoadingState(message: 'جاري تحميل سجل أصناف الشراء...'),
          ),
          error: (err, stack) => Center(
            child: AppErrorState(
              error: err,
              message: 'تعذر تحميل دليل الأصناف: $err',
              onRetry: () => ref.invalidate(masterItemsProvider),
            ),
          ),
          data: (state) {
            final items = state.items;
            if (items.isEmpty) {
              return const Center(
                child: AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'دليل الأصناف فارغ',
                  subtitle:
                      'لا توجد أصناف رئيسية مسجلة حالياً لبدء تحليل الأسعار',
                ),
              );
            }

            // Fallback selection to first item if not chosen yet
            final effectiveItemId = selectedItemId ?? items.first.itemId;
            final selectedItem = items.firstWhere(
              (i) => i.itemId == effectiveItemId,
              orElse: () => items.first,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Item Selector & Search Strip
                  _buildItemSelectorBar(
                    context: context,
                    density: density,
                    isDark: isDark,
                    items: items,
                    selectedItem: selectedItem,
                  ),

                  const SizedBox(height: 12),

                  // Selected Item Specs Strip
                  _buildItemSpecsCard(
                    context: context,
                    density: density,
                    isDark: isDark,
                    item: selectedItem,
                  ),

                  const SizedBox(height: 16),

                  // Watch Price Trends for Selected Item
                  Consumer(
                    builder: (context, ref, _) {
                      final trendsAsync = ref.watch(
                          itemPriceTrendsProvider(selectedItem.itemId));

                      return trendsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: AppLoadingState(
                              message:
                                  'جاري تحليل اتجاه الأسعار ومقارنة الصفقات...',
                            ),
                          ),
                        ),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: AppErrorState(
                              error: err,
                              onRetry: () => ref.invalidate(
                                itemPriceTrendsProvider(selectedItem.itemId),
                              ),
                            ),
                          ),
                        ),
                        data: (trends) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. KPI Cards
                              PriceTrendsKpiCards(
                                trends: trends,
                                item: selectedItem,
                              ),

                              const SizedBox(height: 16),

                              // 2. Supplier Comparison Radar Card
                              SupplierComparisonRadarCard(item: selectedItem),

                              const SizedBox(height: 16),

                              // 3. Price History Timeline Table
                              PriceHistoryTimelineTable(
                                trends: trends,
                                onInspectBreakdown: _openBreakdown,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemSelectorBar({
    required BuildContext context,
    required DisplayDensityMode density,
    required bool isDark,
    required List<MasterItemModel> items,
    required MasterItemModel selectedItem,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          Icon(
            Icons.category_rounded,
            size: 20,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.cobalt,
          ),
          const SizedBox(width: 10),
          Text(
            'الصنف المستهدف للتحليل:',
            style: TextStyle(
              fontSize: density.tableHeaderFontSize,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 0.8,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedItem.itemId,
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  items: items.map((item) {
                    return DropdownMenuItem<int>(
                      value: item.itemId,
                      child: Text(
                        '${item.itemCode} - ${item.descriptionAr}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: density.inputFontSize,
                          fontWeight: item.itemId == selectedItem.itemId
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      ref.read(selectedMasterItemIdProvider.notifier).state =
                          newId;
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const MasterItemsCategoryFilter(width: 160),
        ],
      ),
    );
  }

  Widget _buildItemSpecsCard({
    required BuildContext context,
    required DisplayDensityMode density,
    required bool isDark,
    required MasterItemModel item,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecorationOf(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSpecChip(
              label: 'كود الصنف',
              value: item.itemCode,
              color: AppTheme.cobalt,
              isCode: true,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'البند الجمركي',
              value: item.hsCode ?? 'غير محدد',
              color: const Color(0xFF8E44AD),
              isCode: true,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'الضريبة الجمركية',
              value: '${item.lastCustomsDutyPct?.toStringAsFixed(1) ?? '0.0'}%',
              color: AppTheme.flatEmerald,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'ضريبة القيمة المضافة',
              value: '${item.lastVatPct?.toStringAsFixed(1) ?? '14.0'}%',
              color: AppTheme.flatEmerald,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'وحدة القياس',
              value: item.defaultUom,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'الحجم للوحدة',
              value: '${item.cbmPerUnit} CBM',
              color: AppTheme.flatOrange,
            ),
            const SizedBox(width: 14),
            _buildSpecChip(
              label: 'الوزن القائم',
              value: '${item.grossWeightKg} KG',
              color: AppTheme.flatCobalt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecChip({
    required String label,
    required String value,
    required Color color,
    bool isCode = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11.5,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: isCode ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

const _dummyItem = MasterItemModel(
  itemId: 0,
  itemCode: '',
  descriptionAr: '',
);
