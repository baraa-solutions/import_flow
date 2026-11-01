import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/import_documentation_model.dart';
import '../../idoc_ui_b.dart';
import '../bank_form4_dialogs.dart';
import '../bank_form4_localizer.dart';

/// Stage 3: Bank Linkage card for BankForm4SwiftCard
class BankForm4Stage3BankLinkageCard extends StatelessWidget {
  final BankingDocumentModel doc;
  final bool isDark;
  final VoidCallback onRefresh;

  const BankForm4Stage3BankLinkageCard({
    super.key,
    required this.doc,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = doc.nafezaLinkedBankId != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppTheme.wcagEmerald : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.link,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  BankForm4Localizer.stage3Title(context),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BankForm4Localizer.stage3Subtitle(context),
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDone ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doc.swiftExecutingBankName != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: AppTheme.wcagCobalt),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          BankForm4Localizer.stage3SwiftBank(context, doc.swiftExecutingBankName!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagCobalt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isDone
                            ? BankForm4Localizer.stage3LinkedBank(
                                context,
                                doc.nafezaLinkedBankName ??
                                    (BankForm4Localizer.isArabic(context) ? "تم الربط" : "Linked"))
                            : BankForm4Localizer.stage3NotLinked(context),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDone ? AppTheme.wcagEmerald : AppTheme.crimson,
                        ),
                      ),
                    ),
                    if (isDone) const Icon(Icons.check, size: 16, color: AppTheme.wcagEmerald),
                  ],
                ),
                const SizedBox(height: 8),
                IdocBUi.fit(AppButton(
                  label: BankForm4Localizer.stage3Btn(context, isDone),
                  icon: Icons.link,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => BankForm4Dialogs.showNafezaBankLink(
                    context,
                    doc: doc,
                    onSubmitted: onRefresh,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
