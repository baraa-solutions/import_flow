import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/financial_approval_model.dart';

import 'package:frontend/core/widgets/ltr_text.dart';

/// Search and Clone Previous Payment Request Dialog (UX-CLONE-012)
///
/// Allows users to quickly search previous payment requests by code,
/// supplier, title, or import file, and select one to clone into a new draft.
class SearchAndClonePaymentDialog extends StatefulWidget {
  final List<PaymentRequestModel> payments;
  final ValueChanged<PaymentRequestModel> onSelectPayment;

  const SearchAndClonePaymentDialog({
    super.key,
    required this.payments,
    required this.onSelectPayment,
  });

  @override
  State<SearchAndClonePaymentDialog> createState() =>
      _SearchAndClonePaymentDialogState();
}

class _SearchAndClonePaymentDialogState
    extends State<SearchAndClonePaymentDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<PaymentRequestModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.payments;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = widget.payments;
      } else {
        _filtered = widget.payments.where((p) {
          final code = p.paymentCode.toLowerCase();
          final title = p.title.toLowerCase();
          final sup = p.supplierName.toLowerCase();
          final ben = (p.beneficiaryName ?? '').toLowerCase();
          final file = (p.importFileCode ?? '').toLowerCase();
          final notes = (p.notes ?? '').toLowerCase();
          return code.contains(lower) ||
              title.contains(lower) ||
              sup.contains(lower) ||
              ben.contains(lower) ||
              file.contains(lower) ||
              notes.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.control_point_duplicate_rounded,
                        color: AppTheme.cobalt, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndClonePaymentRequestDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndClonePaymentRequestSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                controller: _queryController,
                onChanged: _filter,
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: l.searchByPaymentCodeOrSupplierHint,
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(Icons.search,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      size: 20),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkInputBackground
                      : AppTheme.charcoalSurface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppTheme.cobalt, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Results Count Banner
              Text(
                ' ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // List of Payment Requests
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              l.noMatchingPaymentRequestsFound,
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final p = _filtered[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectPayment(p);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkElevatedSurface
                                    : AppTheme.charcoalSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.cloudWhite,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Code + Status Row
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cobalt
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: AppTheme.cobalt
                                                        .withOpacity(0.3)),
                                              ),
                                              child: LtrText(
                                                p.paymentCode,
                                                style: const TextStyle(
                                                  color: AppTheme.cobalt,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color:
                                                    (p.status == 'Approved' ||
                                                            p.status == 'Paid')
                                                        ? AppTheme.emerald
                                                            .withOpacity(0.12)
                                                        : AppTheme.orange
                                                            .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p.status,
                                                style: TextStyle(
                                                  color: (p.status ==
                                                              'Approved' ||
                                                          p.status == 'Paid')
                                                      ? AppTheme.emerald
                                                      : AppTheme.wcagOrange,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              p.paymentType,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Title
                                        Text(
                                          p.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark
                                                ? AppTheme.darkTextPrimary
                                                : AppTheme.charcoal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        // Supplier & Bank details
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.business_outlined,
                                                    size: 12,
                                                    color: isDark
                                                        ? AppTheme
                                                            .darkTextSecondary
                                                        : AppTheme
                                                            .textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  p.supplierName,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? AppTheme
                                                              .darkTextSecondary
                                                          : AppTheme
                                                              .textStrong),
                                                ),
                                              ],
                                            ),
                                            if (p.bankName != null &&
                                                p.bankName!.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .account_balance_outlined,
                                                      size: 12,
                                                      color: isDark
                                                          ? AppTheme
                                                              .darkTextSecondary
                                                          : AppTheme
                                                              .textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${p.bankName} (${p.swiftCode ?? ""})',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? AppTheme
                                                                .darkTextSecondary
                                                            : AppTheme
                                                                .textStrong),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Amount Badge
                                        Row(
                                          children: [
                                            Text(
                                              '${p.requestedAmount.toStringAsFixed(2)} ${p.currencyCode}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.emerald,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '≈ ${(p.requestedAmount * p.exchangeRate).toStringAsFixed(2)} EGP',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.cobalt,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
