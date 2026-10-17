import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';

void showRouteIntelligenceDialog(BuildContext context, WidgetRef ref, {
  required int supplierId,
  required String supplierName,
}) {
  showDialog(
    context: context,
    builder: (ctx) => RouteIntelligenceDialog(
      supplierId: supplierId,
      supplierName: supplierName,
    ),
  );
}

class RouteIntelligenceDialog extends ConsumerStatefulWidget {
  final int supplierId;
  final String supplierName;

  const RouteIntelligenceDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  ConsumerState<RouteIntelligenceDialog> createState() => _RouteIntelligenceDialogState();
}

class _RouteIntelligenceDialogState extends ConsumerState<RouteIntelligenceDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _card;

  @override
  void initState() {
    super.initState();
    _fetchIntelligenceCard();
  }

  Future<void> _fetchIntelligenceCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/route-intelligence/supplier/${widget.supplierId}');
      if (mounted) {
        setState(() {
          _card = res.data is Map<String, dynamic> ? res.data : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 820,
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SizedBox(
                      height: 250,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppTheme.crimson)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchIntelligenceCard,
                              child: Text(l10n.retryConnectionBtn),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final country = _card?['country_name'] ?? _card?['country'] ?? '';
    final code = _card?['country_code'] ?? _card?['supplier_code'] ?? '';
    final avgCycleDays = _card?['average_cycle_days'] ?? _card?['last_actual_lead_time_days'] ?? 0;
    
    final rawPoints = isArabic
        ? (_card?['advisory_points_ar'] as List<dynamic>?)
        : (_card?['advisory_points_en'] as List<dynamic>?);
    final recommendation = isArabic
        ? (_card?['executive_recommendation_ar'] ?? _card?['advisory_recommendation_ar'] ?? '').toString()
        : (_card?['executive_recommendation_en'] ?? _card?['advisory_recommendation_en'] ?? _card?['executive_recommendation_ar'] ?? '').toString();

    List<String> recommendationPoints = [];
    if (rawPoints != null && rawPoints.isNotEmpty) {
      recommendationPoints = rawPoints.map((e) => e.toString()).toList();
    } else if (recommendation.isNotEmpty) {
      final lines = recommendation.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      recommendationPoints = lines.where((l) => !l.startsWith('تقرير استشاري') && !l.startsWith('Executive AI')).toList();
      if (recommendationPoints.isEmpty) {
        recommendationPoints = [recommendation];
      }
    }

    final historicalPrices = (_card?['historical_prices'] ?? _card?['items_price_history']) as List<dynamic>? ?? [];
    final recentFreight = (_card?['recent_freight'] ?? _card?['shipping_memory']) as Map<String, dynamic>?;
    final clearance = (_card?['customs_clearance'] ?? _card?['customs_memory']) as Map<String, dynamic>?;
    final notes = (_card?['operational_notes'] as List<dynamic>?) ?? [];
    final avgTransitDays = recentFreight?['average_transit_days'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.routeIntelligenceDialogTitle,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    Text(
                      '${l10n.supplierCompanyNameLabel}: ${widget.supplierName}  •  ${l10n.supplierCountryLabel}: $country ($code)',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(l10n.routeIntelligenceCopyDossierBtn),
                onPressed: () {
                  final dossier = '''
${l10n.routeIntelligenceDialogTitle}
- ${l10n.supplierCompanyNameLabel}: ${widget.supplierName}
- ${l10n.supplierCountryLabel}: $country ($code)
- ${l10n.routeIntelligenceAvgCycleDays}: $avgCycleDays ${l10n.routeIntelligenceDaysSuffix}
- ${l10n.routeIntelligenceAverageTransitDays}: $avgTransitDays ${l10n.routeIntelligenceDaysSuffix}
- ${l10n.routeIntelligenceRecentFreight}: \$${recentFreight?['freight_cost_usd'] ?? recentFreight?['last_ocean_freight_cost'] ?? 0}
- ${l10n.routeIntelligenceRecentClearance}: ${clearance?['clearance_fee_egp'] ?? clearance?['last_clearance_fees_egp'] ?? 0} ${l10n.routeIntelligenceCurrencyEgp}
- ${l10n.routeIntelligenceAiRecommendationTitle}: $recommendation
''';
                  CopyHelper.copy(context, dossier.trim(), customMessage: l10n.routeIntelligenceDossierCopied);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Executive AI Recommendation Banner
          if (recommendation.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cobalt.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.routeIntelligenceAiRecommendationTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13.5),
                        ),
                        const SizedBox(height: 10),
                        if (recommendationPoints.isNotEmpty) ...[
                          for (int i = 0; i < recommendationPoints.length; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i < recommendationPoints.length - 1 ? 8.0 : 0.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    margin: const EdgeInsetsDirectional.only(end: 8, top: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: AppTheme.cobalt,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      recommendationPoints[i].replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                                      style: TextStyle(
                                        color: Colors.grey.shade900,
                                        fontSize: 12.5,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else
                          Text(
                            recommendation,
                            style: TextStyle(color: Colors.grey.shade900, fontSize: 13, height: 1.4),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Top KPI Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  l10n.routeIntelligenceAvgCycleDays,
                  '$avgCycleDays ${l10n.routeIntelligenceDaysSuffix}',
                  Icons.timelapse_outlined,
                  AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  l10n.routeIntelligenceAverageTransitDays,
                  '$avgTransitDays ${l10n.routeIntelligenceDaysSuffix}',
                  Icons.sailing_outlined,
                  AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  l10n.routeIntelligenceRecentFreight,
                  recentFreight != null
                      ? '\$${(recentFreight['freight_cost_usd'] ?? recentFreight['last_ocean_freight_cost'] ?? 0)}'
                      : l10n.routeIntelligenceNotRecorded,
                  Icons.directions_boat_outlined,
                  AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  l10n.routeIntelligenceRecentClearance,
                  clearance != null
                      ? '${(clearance['clearance_fee_egp'] ?? clearance['last_clearance_fees_egp'] ?? 0)} ${l10n.routeIntelligenceCurrencyEgp}'
                      : l10n.routeIntelligenceNotRecorded,
                  Icons.receipt_outlined,
                  AppTheme.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Historical Item Prices
          Text('📊 ${l10n.routeIntelligenceItemPricesTitle}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal)),
          const SizedBox(height: 8),
          if (historicalPrices.isEmpty)
            Text(l10n.routeIntelligenceNoPurchasesYet, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
          else
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(1.3),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(l10n.routeIntelligenceItemCodeCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(l10n.routeIntelligenceItemDescCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(l10n.routeIntelligenceLastUnitPriceCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(l10n.routeIntelligencePriceChangeCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(l10n.routeIntelligenceOrderCodeCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                ...historicalPrices.map((p) {
                  final pct = p['price_change_percentage'];
                  Color pctColor = AppTheme.charcoal;
                  String pctText = '-';
                  if (pct != null) {
                    final num val = pct as num;
                    if (val > 0) {
                      pctColor = AppTheme.crimson;
                      pctText = '+$val%';
                    } else if (val < 0) {
                      pctColor = AppTheme.emerald;
                      pctText = '$val%';
                    } else {
                      pctText = '0%';
                    }
                  }
                  final desc = p['item_description'] ?? p['description_ar'] ?? '';
                  final poCode = p['order_code'] ?? p['last_po_code'] ?? '';
                  final price = p['last_unit_price'] ?? 0;
                  final curr = p['currency'] ?? 'USD';

                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text(p['item_code'] ?? '', style: const TextStyle(fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(desc, style: const TextStyle(fontSize: 12))),
                      Padding(padding: const EdgeInsets.all(8), child: Text('$curr $price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          pctText,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: pctColor),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(8), child: Text(poCode, style: const TextStyle(fontSize: 12))),
                    ],
                  );
                }),
              ],
            ),
          const SizedBox(height: 18),

          // Operational Notes & Warnings
          if (notes.isNotEmpty) ...[
            Text('⚠️ ${l10n.routeIntelligenceNotesTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.crimson)),
            const SizedBox(height: 8),
            ...notes.map((n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.crimson),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n.toString(), style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
