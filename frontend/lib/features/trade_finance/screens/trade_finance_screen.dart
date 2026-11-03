import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../providers/trade_finance_provider.dart';
import '../widgets/bank_charges_tab.dart';
import '../widgets/fx_variance_summary_card.dart';
import '../widgets/lc_lifecycle_card.dart';

/// الشاشة التنسيقية لإدارة تمويل الاستيراد والاعتمادات المستندية للموردين (Type A)
class TradeFinanceScreen extends ConsumerWidget {
  final int? initialFileId;

  const TradeFinanceScreen({super.key, this.initialFileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTradeFinanceTabProvider);
    final instrumentsAsync = ref.watch(tradeFinanceInstrumentsProvider);
    final activeInstrument = ref.watch(activeInstrumentProvider);

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'STAGE_TRADE_FINANCE',
        titleAr: 'تمويل الاستيراد واعتمادات الموردين',
        titleEn: 'Trade Finance & Supplier Letters of Credit',
        headerIcon: Icons.account_balance,
        headerColor: AppTheme.cobalt,
        selectedImportFileId: initialFileId,
        selectedIndex: selectedTab,
        onTabSelected: (index) {
          ref.read(selectedTradeFinanceTabProvider.notifier).state = index;
        },
        headerActions: [
          AppButton(
            label: 'تحديث المعاملات',
            icon: Icons.refresh,
            variant: AppButtonVariant.ghost,
            onPressed: () => ref.invalidate(tradeFinanceInstrumentsProvider),
          ),
        ],
        tabs: const [
          VerticalNavTabItem(
            icon: Icons.description_outlined,
            titleAr: 'دورة حياة الاعتماد المستندي',
            titleEn: 'Letter of Credit Lifecycle',
          ),
          VerticalNavTabItem(
            icon: Icons.receipt_long_outlined,
            titleAr: 'المصروفات والعمولات البنكية',
            titleEn: 'Bank Charges & Commissions',
          ),
          VerticalNavTabItem(
            icon: Icons.currency_exchange_outlined,
            titleAr: 'فروق العملة وعقود التحوط',
            titleEn: 'Exchange Rate Variance & Hedging',
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: instrumentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                  const SizedBox(height: 12),
                  Text('حدث خطأ في تحميل بيانات تمويل الاستيراد: $err'),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'إعادة المحاولة',
                    variant: AppButtonVariant.primary,
                    onPressed: () => ref.invalidate(tradeFinanceInstrumentsProvider),
                  ),
                ],
              ),
            ),
            data: (_) {
              switch (selectedTab) {
                case 1:
                  return BankChargesTab(charges: activeInstrument?.charges ?? []);
                case 2:
                  return FxVarianceSummaryCard(fxRecords: activeInstrument?.fxRecords ?? []);
                case 0:
                default:
                  return LcLifecycleCard(instrument: activeInstrument);
              }
            },
          ),
        ),
      ),
    );
  }
}
