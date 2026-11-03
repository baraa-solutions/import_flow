import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Top header banner for Shipment Inquiry screen
class InquiryScreenHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const InquiryScreenHeader({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          const BackToDashboardButton(),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.travel_explore_rounded, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.inqScreenTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
                Text(
                  l.inqSubtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.cobalt),
            tooltip: l.inqLiveRefreshTooltip,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
