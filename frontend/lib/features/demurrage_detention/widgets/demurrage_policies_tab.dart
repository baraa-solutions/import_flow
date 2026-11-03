import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import 'demurrage_form_dialogs.dart';
import 'demurrage_tracking_card.dart';

class DemurragePoliciesTab extends ConsumerWidget {
  const DemurragePoliciesTab({super.key});

  void _copyPoliciesTsv(BuildContext context, List<DemurragePolicyModel> policies) {
    final l10n = context.l10n;
    final headers = [
      l10n.policiesTsvHeaderCarrier,
      l10n.policiesTsvHeaderContainerType,
      l10n.policiesTsvHeaderDemurrageFreeDays,
      l10n.policiesTsvHeaderDetentionFreeDays,
      l10n.policiesTsvHeaderPortStorageFreeDays,
      l10n.policiesTsvHeaderDailyStorageRateEgp,
      l10n.policiesTsvHeaderCurrency,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final p in policies) {
      final row = [
        p.carrierName,
        p.containerType,
        p.demurrageFreeDays.toString(),
        p.detentionFreeDays.toString(),
        p.portStorageFreeDays.toString(),
        p.portStorageDailyRateEgp.toStringAsFixed(2),
        p.currency,
      ];
      buffer.writeln(row.join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.policiesExportTsvSuccess,
    );
  }

  void _copyPolicySummary(BuildContext context, DemurragePolicyModel p) {
    final l10n = context.l10n;
    final buffer = StringBuffer()
      ..writeln('${l10n.policiesTsvHeaderCarrier}:\t${p.carrierName}')
      ..writeln('${l10n.policiesTsvHeaderContainerType}:\t${p.containerType}')
      ..writeln('${l10n.policiesTsvHeaderDemurrageFreeDays}:\t${l10n.daysCountFormatted(p.demurrageFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderDetentionFreeDays}:\t${l10n.daysCountFormatted(p.detentionFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderPortStorageFreeDays}:\t${l10n.daysCountFormatted(p.portStorageFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderDailyStorageRateEgp}:\t${p.portStorageDailyRateEgp}')
      ..writeln('${l10n.policiesTsvHeaderCurrency}:\t${p.currency}');
    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.policyCopySummarySuccess);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(demurrageProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.carrierTariffPoliciesTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.carrierTariffPoliciesSubtitle,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CcUi.fit(AppButton(
                    label: l10n.policiesExportTsvBtn,
                    icon: Icons.copy_all_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                    onPressed: state.policies.isEmpty ? null : () => _copyPoliciesTsv(context, state.policies),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.demurrageExportExcelBtn,
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: state.policies.isEmpty
                        ? null
                        : () => MasterDataExportService.exportDemurragePoliciesToExcel(
                              context,
                              state.policies,
                              isAr: isAr,
                            ),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.addCarrierPolicyBtn,
                    icon: Icons.add,
                    size: AppButtonSize.small,
                    onPressed: () => AddPolicyDialog.show(context),
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.policies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: CcStateView.empty(
                message: l10n.noCarrierPoliciesFound,
                icon: Icons.policy_outlined,
                actionLabel: l10n.addCarrierPolicyBtn,
                onAction: () => AddPolicyDialog.show(context),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.policies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final p = state.policies[i];
                return DemurragePolicyCard(policy: p, onCopy: () => _copyPolicySummary(context, p));
              },
            ),
        ],
      ),
    );
  }
}
