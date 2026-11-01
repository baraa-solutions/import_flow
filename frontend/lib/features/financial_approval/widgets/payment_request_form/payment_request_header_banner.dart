import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../financial_ui.dart';

class PaymentRequestHeaderBanner extends StatelessWidget {
  final int? editingPaymentId;
  final String? editingPaymentCode;
  final VoidCallback onCancelEdit;
  final bool isLoadingPayPrefill;
  final VoidCallback onSearchAndClone;
  final Widget? swiftExtractorWidget;
  final BoxConstraints constraints;

  const PaymentRequestHeaderBanner({
    super.key,
    this.editingPaymentId,
    this.editingPaymentCode,
    required this.onCancelEdit,
    required this.isLoadingPayPrefill,
    required this.onSearchAndClone,
    this.swiftExtractorWidget,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edit Mode Active Banner
        if (editingPaymentId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l.activeEditModeBanner}: $editingPaymentCode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                    ),
                  ),
                ),
                FinancialUi.fit(AppButton(
                  label: l.cancelEdit,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.close,
                  onPressed: onCancelEdit,
                )),
              ],
            ),
          ),

        // Header with Title & Search/Clone Action
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          spacing: 12,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 400
                    ? constraints.maxWidth - 200
                    : constraints.maxWidth,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      editingPaymentId != null
                          ? '${l.editPaymentRequestTitle} ($editingPaymentCode)'
                          : l.createPaymentRequestTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoadingPayPrefill) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
            FinancialUi.fit(AppButton(
              key: const ValueKey('searchAndClonePaymentRequestBtn'),
              label: l.searchAndClonePaymentRequestBtn,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              icon: Icons.copy_all,
              onPressed: onSearchAndClone,
            )),
          ],
        ),
        const Divider(),
        const SizedBox(height: 6),

        // Smart AI SWIFT MT103 Interactive Extractor
        if (swiftExtractorWidget != null) ...[
          swiftExtractorWidget!,
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
