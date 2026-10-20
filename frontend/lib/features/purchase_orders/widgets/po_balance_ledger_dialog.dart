import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';

void showPOBalanceLedgerDialog(BuildContext context, WidgetRef ref, {required int poId, required String poCode}) {
  showDialog(
    context: context,
    builder: (ctx) => POBalanceLedgerDialog(poId: poId, poCode: poCode),
  );
}

class POBalanceLedgerDialog extends ConsumerStatefulWidget {
  final int poId;
  final String poCode;

  const POBalanceLedgerDialog({super.key, required this.poId, required this.poCode});

  @override
  ConsumerState<POBalanceLedgerDialog> createState() => _POBalanceLedgerDialogState();
}

class _POBalanceLedgerDialogState extends ConsumerState<POBalanceLedgerDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _balanceData;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Dialog disposed');
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    _cancelToken = CancelToken();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/purchase-orders/${widget.poId}/balance',
        cancelToken: _cancelToken,
      );
      if (mounted) {
        setState(() {
          _balanceData = res.data is Map<String, dynamic> ? res.data : null;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // Dialog disposed — ignore
      if (mounted) {
        setState(() {
          _error = e.message ?? e.toString();
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
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SelectionArea(
      child: Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
        width: 860,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? SizedBox(
                height: 320,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l.poBalanceLoading, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
                    ],
                  ),
                ),
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
                          Text(l.poBalanceLoadError(_error!), style: const TextStyle(color: AppTheme.crimson)),
                          const SizedBox(height: 12),
                          AppButton(
                            label: l.retry,
                            variant: AppButtonVariant.primary,
                            onPressed: _fetchBalance,
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildContent(context, isDark),
        ),
      ),
    );
  }

  /// First present numeric value of [keys] (backend contract name first, legacy name second).
  static double _num(Map? m, List<String> keys) {
    for (final k in keys) {
      final v = m?[k];
      if (v is num) return v.toDouble();
    }
    return 0.0;
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final l = context.l10n;
    final orderedQty = _num(_balanceData, ['total_ordered_qty', 'total_ordered_quantity']);
    final shippedQty = _num(_balanceData, ['total_shipped_qty', 'total_shipped_quantity']);
    final remainingQty = _num(_balanceData, ['total_remaining_qty', 'total_remaining_quantity']);

    final orderedUsd = _num(_balanceData, ['total_ordered_amount_fob', 'total_ordered_fob_usd']);
    final shippedUsd = _num(_balanceData, ['total_shipped_amount_fob', 'total_shipped_fob_usd']);
    final remainingUsd = _num(_balanceData, ['total_remaining_amount_fob', 'total_remaining_fob_usd']);
    final currency = (_balanceData?['currency_code'] as String?)?.trim();
    final currencyPrefix = (currency != null && currency.isNotEmpty) ? '$currency ' : '';

    // Value-weighted percentage computed by the backend: shown as is, never recomputed here.
    final fulfillment = _num(_balanceData, ['overall_fulfillment_percent', 'fulfillment_percentage']);
    final fulfillmentStatus = _balanceData?['fulfillment_status'];
    final isFullyShipped = _balanceData?['is_fully_shipped'] == true ||
        fulfillmentStatus == 'Fully Shipped' ||
        fulfillmentStatus == 'Over-Shipped';
    final items = (_balanceData?['line_items_balance'] as List<dynamic>?) ??
        (_balanceData?['line_items'] as List<dynamic>?) ??
        [];

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
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.poBalanceLedgerTitle,
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    Text(
                      l.poBalanceSubTitle(widget.poCode, fulfillment.toStringAsFixed(1)),
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),

          // Fulfillment Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFullyShipped ? l.poBalanceFullyShipped : l.poBalancePartialInProgress,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFullyShipped ? AppTheme.emerald : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '${fulfillment.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.cobalt),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (fulfillment / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                    valueColor: AlwaysStoppedAnimation<Color>(isFullyShipped ? AppTheme.emerald : AppTheme.cobalt),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Metric Cards: Ordered vs Shipped vs Remaining
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: l.poBalanceTotalOrderedQty,
                  qtyText: '${orderedQty.toStringAsFixed(0)} ${l.poBalanceUnit}',
                  usdText: l.poBalanceValue('$currencyPrefix${orderedUsd.toStringAsFixed(2)}'),
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  icon: Icons.inventory_2_outlined,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: l.poBalanceActuallyShippedQty,
                  qtyText: '${shippedQty.toStringAsFixed(0)} ${l.poBalanceUnit}',
                  usdText: l.poBalanceValue('$currencyPrefix${shippedUsd.toStringAsFixed(2)}'),
                  color: AppTheme.emerald,
                  icon: Icons.local_shipping_outlined,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: l.poBalanceRemainingQty,
                  qtyText: '${remainingQty.toStringAsFixed(0)} ${l.poBalanceUnit}',
                  usdText: l.poBalanceValue('$currencyPrefix${remainingUsd.toStringAsFixed(2)}'),
                  color: remainingQty > 0 ? AppTheme.orange : AppTheme.emerald,
                  icon: Icons.hourglass_bottom_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Items Table
          Text(l.poBalanceLineItemsTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface),
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColItemCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColDescription, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColOrderedQty, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColShippedQty, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColRemaining, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.poBalanceColStatus, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                ],
              ),
              ...items.map((it) {
                final rem = _num(it as Map, ['remaining_qty', 'remaining_quantity']);
                final isDone = it['is_fully_shipped'] == true || (rem <= 0 && _num(it, ['ordered_qty', 'ordered_quantity']) > 0);
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(it['item_code'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                    Padding(padding: const EdgeInsets.all(8), child: Text((it['description_ar'] ?? it['description'] ?? '').toString(), style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${_num(it, ['ordered_qty', 'ordered_quantity'])}', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${_num(it, ['shipped_qty', 'shipped_quantity'])}', style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('$rem', style: TextStyle(color: rem > 0 ? AppTheme.orange : AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDone ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDone ? l.poBalanceStatusCompleted : l.poBalanceStatusPartial,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone ? AppTheme.emerald : AppTheme.orange,
                          ),
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

  Widget _buildSummaryCard({
    required String title,
    required String qtyText,
    required String usdText,
    required Color color,
    required IconData icon,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(qtyText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(usdText, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
