import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';

class HsCodeAgreementsTab extends ConsumerWidget {
  final CustomsTariffModel tariff;

  const HsCodeAgreementsTab({super.key, required this.tariff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(customsTariffProvider.notifier).fetchAgreements(tariff.hsCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState.section();
        }

        final agreements = snapshot.data ?? [];
        if (agreements.isEmpty) {
          return AppEmptyState(
            icon: Icons.policy_outlined,
            message: l.hsNoAgreementsFound,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: agreements.length,
          itemBuilder: (context, idx) {
            final ag = agreements[idx];
            final prefRate = ag['preferential_duty_rate'] ?? 0.0;
            final isZero = prefRate == 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isZero ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(
                    Icons.handshake_outlined,
                    color: isZero ? AppTheme.emerald : AppTheme.orange,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      ag['agreement_name'] ?? l.hsDefaultAgreementName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    if (ag['publication_notice'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blueGrey.shade300),
                        ),
                        child: Text(
                          ag['publication_notice'],
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ag['required_document'] != null)
                        Text(l.hsRequiredDocPrefix(ag['required_document']), style: const TextStyle(fontSize: 11)),
                      if (ag['conditions_note'] != null)
                        Text(l.hsConditionsPrefix(ag['conditions_note']),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isZero ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isZero ? Colors.green.shade300 : Colors.amber.shade300),
                      ),
                      child: Text(
                        isZero ? l.hsFullExemptionBadge : l.hsReducedRateBadge(prefRate),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isZero ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                      tooltip: l.hsExplorerCopyCardRateTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () {
                        final agName = ag['agreement_name'] ?? l.hsDefaultAgreementName;
                        final rateText = isZero ? l.hsFullExemptionBadge : l.hsReducedRateBadge(prefRate);
                        CopyHelper.copy(context, '$agName: $rateText');
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
