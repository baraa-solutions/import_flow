import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';

void showSupplierScorecardDialog(
  BuildContext context,
  WidgetRef ref, {
  required int supplierId,
  required String supplierName,
  required String country,
}) {
  showDialog(
    context: context,
    builder: (ctx) => SupplierScorecardDialog(
      supplierId: supplierId,
      supplierName: supplierName,
      country: country,
    ),
  );
}

class SupplierScorecardDialog extends ConsumerStatefulWidget {
  final int supplierId;
  final String supplierName;
  final String country;

  const SupplierScorecardDialog({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.country,
  });

  @override
  ConsumerState<SupplierScorecardDialog> createState() => _SupplierScorecardDialogState();
}

class _SupplierScorecardDialogState extends ConsumerState<SupplierScorecardDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _scorecard;

  @override
  void initState() {
    super.initState();
    _fetchScorecard();
  }

  Future<void> _fetchScorecard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/suppliers/${widget.supplierId}/scorecard');
      if (mounted) {
        setState(() {
          _scorecard = res.data is Map<String, dynamic> ? res.data : null;
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
                              onPressed: _fetchScorecard,
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
    final qualityScore = (_scorecard?['quality_score_out_of_100'] as num?)?.toDouble() ?? 0.0;
    final starRating = (_scorecard?['star_rating'] as num?)?.toDouble() ?? 4.0;
    final tier = _scorecard?['tier_badge']?.toString() ?? 'Gold A';
    final totalOrders = _scorecard?['total_orders_completed'] ?? 0;
    final crdRate = (_scorecard?['crd_adherence_rate'] as num?)?.toDouble() ?? 0.0;
    final docAccuracy = (_scorecard?['documentation_accuracy_rate'] as num?)?.toDouble() ?? 0.0;
    final fulfillmentRate = (_scorecard?['order_fulfillment_rate'] as num?)?.toDouble() ?? 0.0;
    final summaryAr = _scorecard?['executive_summary_ar']?.toString() ?? '';

    Color tierColor;
    if (tier.contains('Platinum')) {
      tierColor = AppTheme.emerald;
    } else if (tier.contains('Gold')) {
      tierColor = AppTheme.cobalt;
    } else if (tier.contains('Silver')) {
      tierColor = AppTheme.orange;
    } else {
      tierColor = AppTheme.crimson;
    }

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
                  color: tierColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.verified_outlined, color: tierColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supplierScorecardTitle,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.supplierScorecardSubtitle(widget.supplierName, widget.country),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Score and Tier Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tierColor.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ' / 100',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: tierColor),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < starRating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber.shade700,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: tierColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tier,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.supplierScorecardTotalOrders(totalOrders),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // KPI Metrics Grid
          Text(
            l10n.scorecardKpiHeader,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: l10n.supplierScorecardCrdRate,
                  value: '%',
                  icon: Icons.event_available,
                  color: AppTheme.cobalt,
                  subtext: 'Cargo Readiness Adherence',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: l10n.supplierScorecardDocAccuracy,
                  value: '%',
                  icon: Icons.fact_check_outlined,
                  color: AppTheme.emerald,
                  subtext: 'Clean Customs Documentation',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: l10n.supplierScorecardFulfillmentRate,
                  value: '%',
                  icon: Icons.assignment_turned_in_outlined,
                  color: AppTheme.orange,
                  subtext: 'Purchase Order Delivery',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Executive Summary Box
          if (summaryAr.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.charcoal),
                      const SizedBox(width: 8),
                      Text(
                        l10n.scorecardDialogTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: l10n.partnerCopySummaryBtn,
                        onPressed: () => CopyHelper.copy(
                          context,
                          summaryAr,
                          customMessage: l10n.supplierScorecardCopySuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summaryAr,
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.charcoal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Footer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l10n.partnerCopySummaryBtn),
                onPressed: () {
                  final buffer = StringBuffer()
                    ..writeln('Supplier Scorecard: ${widget.supplierName}')
                    ..writeln('Quality Score: ${qualityScore.toStringAsFixed(1)}/100 (Tier: $tier)')
                    ..writeln('CRD Adherence: ${crdRate.toStringAsFixed(1)}%')
                    ..writeln('Doc Accuracy: ${docAccuracy.toStringAsFixed(1)}%')
                    ..writeln('Fulfillment: ${fulfillmentRate.toStringAsFixed(1)}%')
                    ..writeln(summaryAr);
                  CopyHelper.copy(
                    context,
                    buffer.toString(),
                    customMessage: l10n.supplierScorecardCopySuccess,
                  );
                },
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.closeBtn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
