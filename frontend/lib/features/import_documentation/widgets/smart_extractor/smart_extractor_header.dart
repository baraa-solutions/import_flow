import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Top header banner and navigation tabs for the Smart Extractor Dialog.
class SmartExtractorHeader extends StatelessWidget {
  final VoidCallback onClose;

  const SmartExtractorHeader({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.smartExtractorDialogTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l.smartExtractorDialogSubtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
          tooltip: l.invoiceBlMatcherCloseButton,
        ),
      ],
    );
  }
}

/// Styled segmented tab bar for switching between Invoice, B/L, and Audit radar.
class SmartExtractorTabBar extends StatelessWidget {
  final TabController controller;

  const SmartExtractorTabBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        labelColor: AppTheme.white,
        unselectedLabelColor: AppTheme.charcoal,
        indicator: BoxDecoration(
          color: AppTheme.cobalt,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            icon: const Icon(Icons.receipt_long_outlined),
            text: l.smartExtractorTabInvoice,
          ),
          Tab(
            icon: const Icon(Icons.directions_boat_outlined),
            text: l.smartExtractorTabBl,
          ),
          Tab(
            icon: const Icon(Icons.rule_folder_outlined),
            text: l.smartExtractorTabAudit,
          ),
        ],
      ),
    );
  }
}
