import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

/// Stats metric bar displaying envelopes aggregation metrics.
class CargoXHubStatsBar extends StatelessWidget {
  final int totalCount;
  final int acceptedCount;
  final int uploadedCount;
  final int verifiedCount;

  const CargoXHubStatsBar({
    super.key,
    required this.totalCount,
    required this.acceptedCount,
    required this.uploadedCount,
    required this.verifiedCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildMetricCard(
            context,
            context.l10n.cargoxMetricTotalEnvelopes,
            '$totalCount',
            AppTheme.cobalt,
            Icons.markunread_mailbox,
          ),
          _buildMetricCard(
            context,
            context.l10n.cargoxMetricAcceptedCustoms,
            '$acceptedCount',
            AppTheme.emerald,
            Icons.verified,
          ),
          _buildMetricCard(
            context,
            context.l10n.cargoxMetricInProgress,
            '$uploadedCount',
            AppTheme.orange,
            Icons.hourglass_top,
          ),
          _buildMetricCard(
            context,
            context.l10n.cargoxMetricAcidVerified,
            '$verifiedCount',
            Colors.purple,
            Icons.check_circle_outline,
          ),
        ];

        if (constraints.maxWidth < 650) {
          return Column(
            children: cards
                .map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c))
                .toList(),
          );
        }

        return Row(
          children: cards
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: e.key == 0 ? 0 : 6,
                        end: e.key == cards.length - 1 ? 0 : 6,
                      ),
                      child: e.value,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        CopyHelper.copy(
          context,
          '$title: $value',
          customMessage: context.l10n.cargoxCopiedToClipboard,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
