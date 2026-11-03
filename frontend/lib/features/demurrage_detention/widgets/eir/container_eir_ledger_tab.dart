import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../l10n/container_eir_l10n.dart';
import '../../models/container_eir_model.dart';

class ContainerEirLedgerTab extends StatelessWidget {
  final bool isLoading;
  final ContainerLedgerResponseModel? ledgerData;
  final void Function(int id, String number) onSelectForReturn;

  const ContainerEirLedgerTab({
    super.key,
    required this.isLoading,
    required this.ledgerData,
    required this.onSelectForReturn,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = ledgerData;
    if (data == null || data.items.isEmpty) {
      return Center(
        child: Text(l.noContainersFound, style: const TextStyle(fontSize: 14)),
      );
    }

    return Column(
      children: [
        // KPI Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppTheme.surfaceOf(context),
          child: Row(
            children: [
              _buildKpiCard(l.totalContainersLabel, '${data.totalContainers}', AppTheme.cobalt),
              const SizedBox(width: 12),
              _buildKpiCard(l.returnedContainersLabel, '${data.returnedContainers}', AppTheme.flatEmerald),
              const SizedBox(width: 12),
              _buildKpiCard(l.activeContainersLabel, '${data.activeContainers}', AppTheme.crimson),
              const SizedBox(width: 12),
              _buildKpiCard(
                l.totalDemurrageCostLabel,
                '${data.totalDemurrageCostFx.toStringAsFixed(2)} ${data.currency}',
                AppTheme.charcoal,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Containers List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = data.items[index];
              return _buildContainerLedgerCard(context, l, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accentColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerLedgerCard(BuildContext context, AppLocalizations l, ContainerLedgerItemModel item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isDemurrageStopped ? AppTheme.flatEmerald.withValues(alpha: 0.4) : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                item.containerNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: l.copyContainerNumber,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => CopyHelper.copy(context, item.containerNumber),
              ),
              const SizedBox(width: 8),
              Text(
                '[${item.containerType}]',
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
              ),
              const Spacer(),
              if (item.isDemurrageStopped)
                AppStatusBadge(
                  label: l.statusReturnedStopped,
                  severity: AppSeverity.success,
                  icon: Icons.check_circle_outline,
                )
              else
                AppStatusBadge(
                  label: l.statusActiveAccruing,
                  severity: AppSeverity.danger,
                  icon: Icons.timer,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Operational Details
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (item.gateOutDate != null)
                Text(
                  '${l.gateOutDateLabel}: ${item.gateOutDate!.toIso8601String().substring(0, 10)}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
              if (item.emptyReturnDate != null)
                Text(
                  '${l.returnDateLabel}: ${item.emptyReturnDate!.toIso8601String().substring(0, 10)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.flatEmerald, fontWeight: FontWeight.w600),
                ),
              if (item.eirNumber != null && item.eirNumber!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l.eirNumberLabel}: ${item.eirNumber}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: l.copyEirNumber,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => CopyHelper.copy(context, item.eirNumber!),
                    ),
                  ],
                ),
              if (item.eirConditionStatus != null)
                Text(
                  '${l.inspectionConditionLabel}: ${item.eirConditionStatus}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Financial Ledger Line
          Row(
            children: [
              Text(
                '${l.individualDemurrageLabel}: ',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              Text(
                '${item.individualDemurrageCost.toStringAsFixed(2)} ${item.currency}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: item.isDemurrageStopped ? AppTheme.flatEmerald : AppTheme.crimson,
                ),
              ),
              const Spacer(),
              if (!item.isDemurrageStopped)
                AppButton(
                  label: l.confirmEirBtn,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  icon: Icons.assignment_turned_in,
                  onPressed: () => onSelectForReturn(item.containerId, item.containerNumber),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
