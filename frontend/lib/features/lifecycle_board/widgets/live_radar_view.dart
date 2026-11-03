import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/live_polling_provider.dart';
import 'radar_data_table.dart';
import 'radar_filter_bar.dart';
import 'radar_kpi_bar.dart';

/// Live Logistics Tracking Radar view component of the Lifecycle Board.
class LiveRadarView extends ConsumerStatefulWidget {
  final VoidCallback onRefresh;

  const LiveRadarView({
    super.key,
    required this.onRefresh,
  });

  @override
  ConsumerState<LiveRadarView> createState() => _LiveRadarViewState();
}

class _LiveRadarViewState extends ConsumerState<LiveRadarView> {
  String _searchQuery = '';
  String _selectedRiskFilter = 'ALL'; // ALL, CRITICAL, WARNING, SAFE
  String _selectedSampleFilter = 'ALL'; // ALL, TESTING, APPROVED, REJECTED

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _kpiScrollController = ScrollController();
  final ScrollController _radarFilterScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _kpiScrollController.dispose();
    _radarFilterScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radarAsync = ref.watch(livePollingProvider);

    return SelectionArea(
      child: radarAsync.when(
        loading: () => const RadarTableShimmerSkeleton(),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 40),
              const SizedBox(height: 12),
              Text(
                l10n.liveRadarError(err.toString()),
                style: const TextStyle(color: AppTheme.crimson),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (radarData) {
          final isAr = Directionality.of(context) == TextDirection.rtl;
          final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

          final filteredItems = radarData.items.where((item) {
            final q = _searchQuery.toLowerCase().trim();
            final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
              item.importFileCode,
              shipments: allImportFiles,
              isArabic: isAr,
            );
            final matchesSearch = q.isEmpty ||
                item.importFileCode.toLowerCase().contains(q) ||
                shipmentName.toLowerCase().contains(q) ||
                item.companyName.toLowerCase().contains(q) ||
                item.supplierName.toLowerCase().contains(q) ||
                (item.poNumber != null && item.poNumber!.toLowerCase().contains(q)) ||
                (item.blNumber != null && item.blNumber!.toLowerCase().contains(q)) ||
                (item.carrierName != null && item.carrierName!.toLowerCase().contains(q)) ||
                (item.vesselName != null && item.vesselName!.toLowerCase().contains(q));

            bool matchesRisk = true;
            if (_selectedRiskFilter == 'CRITICAL') {
              matchesRisk = item.demurrageRiskLevel == 'Critical';
            } else if (_selectedRiskFilter == 'WARNING') {
              matchesRisk = item.demurrageRiskLevel == 'High' || item.demurrageRiskLevel == 'Medium';
            } else if (_selectedRiskFilter == 'SAFE') {
              matchesRisk = item.demurrageRiskLevel == 'Low';
            }

            bool matchesSample = true;
            if (_selectedSampleFilter == 'TESTING') {
              matchesSample = item.sampleTestStatus == 'Under Testing';
            } else if (_selectedSampleFilter == 'APPROVED') {
              matchesSample = item.sampleTestStatus == 'Approved';
            } else if (_selectedSampleFilter == 'REJECTED') {
              matchesSample = item.sampleTestStatus == 'Rejected';
            }

            return matchesSearch && matchesRisk && matchesSample;
          }).toList();

          return Column(
            children: [
              // Critical Alert Banner — appears automatically when CRITICAL alerts exist
              const CriticalAlertBanner(),

              // UPPER: 5 Strategic KPI Summary Cards with Horizontal Scrollbar
              RadarKpiBar(
                radarData: radarData,
                controller: _kpiScrollController,
              ),

              const Divider(height: 1, color: Colors.black12),

              // MIDDLE: Radar Filter & Search Toolbar with Horizontal Scrollbar
              RadarFilterBar(
                selectedRiskFilter: _selectedRiskFilter,
                selectedSampleFilter: _selectedSampleFilter,
                searchController: _searchController,
                filteredItems: filteredItems,
                allImportFiles: allImportFiles,
                onRiskFilterChanged: (val) => setState(() => _selectedRiskFilter = val),
                onSampleFilterChanged: (val) => setState(() => _selectedSampleFilter = val),
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                controller: _radarFilterScrollController,
              ),

              // LOWER: Radar Data Table
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState(l10n)
                    : RadarDataTable(
                        items: filteredItems,
                        allImportFiles: allImportFiles,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_outlined, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              l10n.noShipmentsInStage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.noShipmentsInStageDesc,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
