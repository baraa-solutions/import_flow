import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_button.dart';
import 'providers/broker_custody_provider.dart';
import 'widgets/advance_payment_header_card.dart';
import 'widgets/official_receipts_grid.dart';
import 'widgets/settlement_variance_footer_bar.dart';

/// نافذة ومنسق تسوية عهدة المخلص الجمركي (Parallel UI Decomposition - <380 lines)
class BrokerCustodyDialog extends ConsumerWidget {
  final int advanceId;

  const BrokerCustodyDialog({super.key, required this.advanceId});

  static Future<void> show(BuildContext context, int advanceId) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BrokerCustodyDialog(advanceId: advanceId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure the selected advance ID is in sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(selectedBrokerAdvanceIdProvider) != advanceId) {
        ref.read(selectedBrokerAdvanceIdProvider.notifier).state = advanceId;
      }
    });

    final advanceAsync = ref.watch(activeBrokerAdvanceProvider);
    final reconciliationAsync = ref.watch(activeAdvanceReconciliationProvider);

    return SelectionArea(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Container(
          width: 1050,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'تسوية ومطابقة عهدة المخلص الجمركي والمستندات الرسمية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ),
                  AppButton(
                    label: 'تحديث',
                    icon: Icons.refresh,
                    variant: AppButtonVariant.ghost,
                    onPressed: () {
                      ref.invalidate(activeBrokerAdvanceProvider);
                      ref.invalidate(activeAdvanceReconciliationProvider);
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'إغلاق',
                    icon: Icons.close,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Area
              Flexible(
                child: advanceAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                        const SizedBox(height: 12),
                        Text('تعذر تحميل بيانات العهدة والتسوية: $err'),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'إعادة المحاولة',
                          variant: AppButtonVariant.primary,
                          onPressed: () {
                            ref.invalidate(activeBrokerAdvanceProvider);
                            ref.invalidate(activeAdvanceReconciliationProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                  data: (advance) {
                    if (advance == null) {
                      return const Center(
                        child: Text('العهدة الجمركية المطلوبة غير موجودة'),
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdvancePaymentHeaderCard(advance: advance),
                          const SizedBox(height: 16),
                          OfficialReceiptsGrid(receipts: advance.receipts),
                          const SizedBox(height: 16),
                          SettlementVarianceFooterBar(
                            reconciliation: reconciliationAsync.value,
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
