import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/purchase_order_model.dart';

// ==================================================
// Dedicated Search & Clone Dialog for Purchase Orders (UX-CLONE-011)
// ==================================================
class PoSearchAndCloneDialog extends StatefulWidget {
  final List<PurchaseOrderModel> orders;
  final ValueChanged<PurchaseOrderModel> onSelectPO;

  const PoSearchAndCloneDialog({
    super.key,
    required this.orders,
    required this.onSelectPO,
  });

  @override
  State<PoSearchAndCloneDialog> createState() => _PoSearchAndCloneDialogState();
}

class _PoSearchAndCloneDialogState extends State<PoSearchAndCloneDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<PurchaseOrderModel> _filteredOrders;

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.orders;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = widget.orders;
      } else {
        _filteredOrders = widget.orders.where((po) {
          final num = po.poNumber.toLowerCase();
          final ref = (po.poReference ?? '').toLowerCase();
          final pi = (po.proformaInvoiceNumber ?? '').toLowerCase();
          final comp = (po.companyName ?? '').toLowerCase();
          final supp = (po.supplierName ?? '').toLowerCase();
          final prj = (po.projectName ?? '').toLowerCase();
          return num.contains(query) ||
              ref.contains(query) ||
              pi.contains(query) ||
              comp.contains(query) ||
              supp.contains(query) ||
              prj.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        child: Container(
          width: math.min(720.0, screenWidth - 32),
          height: math.min(600.0, screenHeight - 64),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.wcagCobalt, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndClonePoDialogTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndClonePoSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
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
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: l.searchByPoOrSupplierOrItemHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _queryController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // List of matching POs
              Expanded(
                child: _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              l.noMatchingPosFound,
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final po = _filteredOrders[idx];
                          final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            po.displayName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                            ),
                                          ),
                                          if (po.displayName != po.poNumber) ...[
                                            const SizedBox(width: 8),
                                            LtrText(
                                              po.poNumber,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${po.companyName ?? "-"} │ ${po.supplierName ?? "-"} │ $amountStr',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AppButton(
                                  label: context.l10n.cloneBtn,
                                  icon: Icons.control_point_duplicate_rounded,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  onPressed: () => widget.onSelectPO(po),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
