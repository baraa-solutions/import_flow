import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/operational_dashboard_provider.dart';

/// Error state card when network or server connection fails on the dashboard.
class OperationalErrorCard extends StatelessWidget {
  final OperationalDashboardNotifier notifier;

  const OperationalErrorCard({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Card(
        elevation: 1,
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: AppTheme.crimson, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.serverConnectionError} (${ApiConstants.serverUrl})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.crimson,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.serverConnectionHint,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
                onPressed: () => notifier.fetchDashboard(),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: Text(
                  l.retry,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state card displayed when no shipments match active filters.
class OperationalEmptyStateCard extends StatelessWidget {
  final OperationalDashboardNotifier notifier;
  final TextEditingController searchController;

  const OperationalEmptyStateCard({
    super.key,
    required this.notifier,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 56,
                color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                l.noMatchingShipments,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.noMatchingShipmentsDesc,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                onPressed: () {
                  searchController.clear();
                  notifier.resetFilters();
                },
                child: Text(
                  l.clearFiltersShowAll,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
