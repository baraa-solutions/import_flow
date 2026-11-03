import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/financial_approval_model.dart';

class PaymentLinkedPosSection extends StatelessWidget {
  final BudgetPrefillModel? payPrefillData;
  final void Function(LinkedPOItemModel po)? onCloneLinkedPoItem;
  final bool isMobile;

  const PaymentLinkedPosSection({
    super.key,
    required this.payPrefillData,
    this.onCloneLinkedPoItem,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (payPrefillData == null || payPrefillData!.linkedPos.isEmpty) {
      return const SizedBox.shrink();
    }

    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l.linkedPurchaseOrdersTitle}:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        if (isMobile)
          _buildMobileLinkedPOCardsList(l, isDark)
        else
          _buildLinkedPOsTable(l, isDark),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMobileLinkedPOCardsList(AppLocalizations l, bool isDark) {
    return Column(
      children: payPrefillData!.linkedPos.map((po) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          po.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                            fontSize: 13,
                          ),
                        ),
                        if (po.displayName != po.poNumber)
                          CopyableText(
                            po.poNumber,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.orangeLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.wcagOrange
                                : AppTheme.orange,
                          ),
                        ),
                        child: Text(
                          po.paymentTerms,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (onCloneLinkedPoItem != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: AppTheme.cobalt),
                          tooltip: l.clonePoAllocationTooltip,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () => onCloneLinkedPoItem!(po),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.invoiceAmount}:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textStrong,
                    ),
                  ),
                  Text(
                    '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.emerald,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLinkedPOsTable(AppLocalizations l, bool isDark) {
    return Table(
      border: TableBorder.all(
        color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.8),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.4),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(0.8),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.poNumberCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.projectNameCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.paymentTypeLabel,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.currencyCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.invoiceAmount,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.statusCol,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l.actionsCol,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        ...payPrefillData!.linkedPos.map((po) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText(
                      po.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                    ),
                    if (po.displayName != po.poNumber)
                      CopyableText(
                        po.poNumber,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(po.projectName ?? '-'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkCardBackground
                        : AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                    ),
                  ),
                  child: CopyableText(
                    po.paymentTerms,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  po.currency,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  '${po.totalAmount.toStringAsFixed(2)} ${po.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: CopyableText(
                  po.status,
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: onCloneLinkedPoItem != null
                    ? IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 16, color: AppTheme.cobalt),
                        tooltip: l.clonePoAllocationTooltip,
                        onPressed: () => onCloneLinkedPoItem!(po),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }),
      ],
    );
  }
}
