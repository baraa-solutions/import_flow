import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/critical_alert_banner.dart';
import '../../../core/widgets/page_header.dart';
import '../../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../../import_documentation/screens/central_docs_archive_screen.dart';
import '../../import_documentation/screens/customs_declaration46_screen.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/screens/import_files_screen.dart';
import '../../import_requirements/screens/import_requirements_screen.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../models/lifecycle_board_model.dart';
import '../providers/lifecycle_board_provider.dart';
import '../providers/live_polling_provider.dart';
import '../services/lifecycle_board_export_service.dart';
import '../widgets/step_action_dialog.dart';
import '../widgets/shipment_timeline_dossier_dialog.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class LifecycleBoardScreen extends ConsumerStatefulWidget {
  const LifecycleBoardScreen({super.key});

  @override
  ConsumerState<LifecycleBoardScreen> createState() => _LifecycleBoardScreenState();
}

class _LifecycleBoardScreenState extends ConsumerState<LifecycleBoardScreen> {
  int _viewModeIndex = 0; // 0: 6-Phase Kanban Board, 1: Live Logistics Tracking Radar
  String _searchQuery = '';
  String? _selectedStepCode;
  int? _selectedPhaseId;

  // Radar Filters
  String _selectedRiskFilter = 'ALL'; // ALL, CRITICAL, WARNING, SAFE
  String _selectedSampleFilter = 'ALL'; // ALL, TESTING, APPROVED, REJECTED

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _topPhasesScrollController = ScrollController();
  final ScrollController _radarHorizontalScrollController = ScrollController();
  final ScrollController _radarVerticalScrollController = ScrollController();
  final ScrollController _kpiScrollController = ScrollController();
  final ScrollController _radarFilterScrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _stepPhases = {
    'STEP_01': '1', 'STEP_02': '1', 'STEP_03': '1',
    'STEP_04': '2', 'STEP_05': '2',
    'STEP_06': '3', 'STEP_07': '3', 'STEP_08': '3',
    'STEP_08_PO': '3', 'STEP_08_BL': '3', 'STEP_08_MATCH': '3', 'STEP_08_COO': '3', 'STEP_08_COC': '3',
    'STEP_09': '3',
    'STEP_10': '4', 'STEP_11': '4', 'STEP_12': '4',
    'STEP_13': '5', 'STEP_14': '5', 'STEP_15': '5', 'STEP_16': '5', 'STEP_17': '5', 'STEP_18': '5',
    'STEP_19': '6', 'STEP_20': '6', 'STEP_21': '6',
  };

  @override
  void initState() {
    super.initState();
    _selectedStepCode = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(liveLogisticsTrackingProvider);
      ref.invalidate(livePollingProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _topPhasesScrollController.dispose();
    _radarHorizontalScrollController.dispose();
    _radarVerticalScrollController.dispose();
    _kpiScrollController.dispose();
    _radarFilterScrollController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(lifecycleBoardSummaryProvider);
    ref.invalidate(liveLogisticsTrackingProvider);
    ref.invalidate(livePollingProvider);
    // CL-006: تشغيل فحص التنبيهات الحرجة عند كل تحديث يدوي
    ref.read(notificationsProvider.notifier).triggerExpiryCheck();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        icon: _viewModeIndex == 0 ? Icons.view_kanban_outlined : Icons.radar_outlined,
        iconColor: AppTheme.cobalt,
        title: _viewModeIndex == 0 ? l10n.lifecycleBoardTitle : l10n.viewModeLiveRadar,
        elevation: 2,
        actions: [
          // Dual View Switcher Segmented Control
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeTab(
                  index: 0,
                  label: l10n.viewModeKanbanPhases,
                  icon: Icons.view_kanban_outlined,
                ),
                _buildViewModeTab(
                  index: 1,
                  label: l10n.viewModeLiveRadar,
                  icon: Icons.radar,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CL-004: مؤشر التحديث الحي (يظهر فقط في وضع الرادار)
          if (_viewModeIndex == 1) ...[
            ref.watch(isRefreshingProvider)
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : ref.watch(refreshCountdownProvider).when(
                    data: (seconds) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: seconds <= 10
                            ? AppTheme.orange.withValues(alpha: 0.3)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: seconds <= 10 ? AppTheme.orange.withValues(alpha: 0.5) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: density.buttonIconSize - 4,
                            color: seconds <= 10 ? AppTheme.orange : Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${seconds}s',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: seconds <= 10 ? AppTheme.orange : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: density.buttonIconSize),
            tooltip: l10n.refreshLiveBoardTooltip,
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 6),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: _viewModeIndex == 0
            ? _buildKanbanPhasesView(context, l10n)
            : _buildLiveLogisticsRadarView(context, l10n),
      ),
    );
  }

  Widget _buildViewModeTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _viewModeIndex == index;
    return InkWell(
      onTap: () => setState(() => _viewModeIndex = index),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEW 1: 6-PHASE KANBAN STAGE BOARD (العرض الكلاسيكي للمراحل الست)
  // ===========================================================================

  Widget _buildKanbanPhasesView(BuildContext context, AppLocalizations l10n) {
    final boardAsync = ref.watch(lifecycleBoardSummaryProvider);

    return boardAsync.when(
      loading: () => const KanbanBoardShimmerSkeleton(),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.crimson, size: 40),
            const SizedBox(height: 12),
            Text(l10n.lifecycleBoardError(err.toString()), style: const TextStyle(color: AppTheme.crimson), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (boardData) {
        final allShipments = boardData.allShipments;
        final isAr = Directionality.of(context) == TextDirection.rtl;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

        final filteredShipments = allShipments.where((s) {
          final matchesStep = _selectedStepCode == null || s.stepCode == _selectedStepCode;
          final matchesPhase = _selectedPhaseId == null || _isStepInPhase(s.stepCode, _selectedPhaseId!, boardData.phases);
          final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(s.importFileCode, shipments: allImportFiles, isArabic: isAr);

          final matchesSearch = _searchQuery.isEmpty ||
              s.importFileCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              shipmentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.companyName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.supplierName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (s.poNumber != null && s.poNumber!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
              (s.notes != null && s.notes!.toLowerCase().contains(_searchQuery.toLowerCase()));

          if (_selectedStepCode != null) {
            return matchesStep && matchesSearch;
          } else if (_selectedPhaseId != null) {
            return matchesPhase && matchesSearch;
          }
          return matchesSearch;
        }).toList();

        return Column(
          children: [
            // UPPER 1/3: Compact 6 Phase Overview Cards
            Container(
              color: isDark ? AppTheme.darkCardBackground : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.layers_outlined, color: AppTheme.cobalt, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              l10n.majorPhasesHeader,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                l10n.totalActiveShipmentsCount(boardData.totalActiveFiles, boardData.allShipments.length),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                              ),
                            ),
                            if (_selectedStepCode != null || _selectedPhaseId != null) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  setState(() {
                                    _selectedStepCode = null;
                                    _selectedPhaseId = null;
                                  });
                                },
                                icon: const Icon(Icons.clear_all, size: 14, color: AppTheme.crimson),
                                label: Text(l10n.showAllPhasesBtn, style: const TextStyle(color: AppTheme.crimson, fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // The 6 Phase Cards Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final cardWidth = availableWidth > 1150
                          ? (availableWidth - 50) / 6.0
                          : 185.0;

                      return SingleChildScrollView(
                        controller: _topPhasesScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: boardData.phases.map((phase) {
                            return _buildPhaseTopCard(phase, cardWidth);
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.black12),

            // LOWER 2/3: Interactive Shipment Data Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTableTopBar(filteredShipments, boardData.phases, allImportFiles),
                      Expanded(
                        child: filteredShipments.isEmpty
                            ? _buildEmptyState()
                            : _buildShipmentsTable(filteredShipments, boardData.phases, allImportFiles),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // VIEW 2: LIVE SHIPMENT LOGISTICS TRACKING RADAR (رادار التتبع اللوجستي الحي)
  // ===========================================================================

  Widget _buildLiveLogisticsRadarView(BuildContext context, AppLocalizations l10n) {
    // CL-004: استخدام livePollingProvider بدلاً من FutureProvider للتحديث التلقائي
    final radarAsync = ref.watch(livePollingProvider);

    return radarAsync.when(
      loading: () => const RadarTableShimmerSkeleton(),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.crimson, size: 40),
            const SizedBox(height: 12),
            Text(l10n.liveRadarError(err.toString()), style: const TextStyle(color: AppTheme.crimson), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (radarData) {
        final isAr = Directionality.of(context) == TextDirection.rtl;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

        final filteredItems = radarData.items.where((item) {
          final q = _searchQuery.toLowerCase().trim();
          final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(item.importFileCode, shipments: allImportFiles, isArabic: isAr);
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
            // CL-006: بانر التنبيهات الحرجة — يظهر تلقائياً عند وجود إشعارات CRITICAL
            const CriticalAlertBanner(),

            // UPPER: 5 Strategic KPI Summary Cards with Horizontal Scrollbar
            Container(
              color: isDark ? AppTheme.darkCardBackground : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SingleChildScrollView(
                controller: _kpiScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildKpiCard(
                      title: l10n.kpiInTransit,
                      value: '${radarData.inTransitCount}',
                      icon: Icons.sailing,
                      color: AppTheme.cobalt,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: l10n.kpiInPort,
                      value: '${radarData.inPortCount}',
                      icon: Icons.anchor,
                      color: const Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: l10n.kpiHighDemurrageRisk,
                      value: '${radarData.highRiskDemurrageCount}',
                      icon: Icons.warning_amber_rounded,
                      color: AppTheme.crimson,
                      isAlert: radarData.highRiskDemurrageCount > 0,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: l10n.kpiUnderTesting,
                      value: '${radarData.underSampleTestingCount}',
                      icon: Icons.biotech,
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      title: l10n.kpiIncompleteDocs,
                      value: '${radarData.incompleteDocumentsCount}',
                      icon: Icons.folder_delete_outlined,
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Colors.black12),

            // MIDDLE: Radar Filter & Search Toolbar with Horizontal Scrollbar
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SingleChildScrollView(
                controller: _radarFilterScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Search Box
                    SizedBox(
                      width: 260,
                      height: 36,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, val, _) {
                          return TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: l10n.searchLiveRadarHint,
                              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.cobalt),
                              suffixIcon: val.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 14),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Risk Level Filter Chips
                    _buildRiskFilterChip('ALL', l10n.riskFilterAll, Colors.grey.shade700),
                    const SizedBox(width: 4),
                    _buildRiskFilterChip('CRITICAL', l10n.riskFilterCritical, AppTheme.crimson),
                    const SizedBox(width: 4),
                    _buildRiskFilterChip('WARNING', l10n.riskFilterWarning, AppTheme.orange),
                    const SizedBox(width: 4),
                    _buildRiskFilterChip('SAFE', l10n.riskFilterSafe, AppTheme.emerald),
                    const SizedBox(width: 12),

                    // Sample Filter Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSampleFilter,
                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.w600),
                          icon: Icon(Icons.arrow_drop_down, size: 18, color: isDark ? AppTheme.darkTextPrimary : null),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSampleFilter = val);
                          },
                          items: [
                            DropdownMenuItem(value: 'ALL', child: Text(l10n.sampleFilterAll)),
                            DropdownMenuItem(value: 'TESTING', child: Text(l10n.sampleFilterUnderTesting)),
                            DropdownMenuItem(value: 'APPROVED', child: Text(l10n.sampleFilterApproved)),
                            DropdownMenuItem(value: 'REJECTED', child: Text(l10n.sampleFilterRejected)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Radar Export Toolbar
                    OutlinedButton.icon(
                      onPressed: filteredItems.isEmpty
                          ? null
                          : () => LifecycleBoardExportService.exportRadarToTsv(
                                context: context,
                                items: filteredItems,
                                allImportFiles: allImportFiles,
                              ),
                      icon: const Icon(Icons.table_chart_outlined, size: 14),
                      label: Text(l10n.lifecycleExportTsvBtn, style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: filteredItems.isEmpty
                          ? null
                          : () => LifecycleBoardExportService.exportRadarToExcel(
                                context: context,
                                items: filteredItems,
                                allImportFiles: allImportFiles,
                              ),
                      icon: const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.emerald),
                      label: Text(l10n.lifecycleExportExcelBtn, style: const TextStyle(fontSize: 11, color: AppTheme.emerald)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: filteredItems.isEmpty
                          ? null
                          : () => LifecycleBoardExportService.printOrSaveRadarPdf(
                                context: context,
                                items: filteredItems,
                                allImportFiles: allImportFiles,
                              ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.crimson),
                      label: Text(l10n.lifecyclePrintPdfBtn, style: const TextStyle(fontSize: 11, color: AppTheme.crimson)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: filteredItems.isEmpty
                          ? null
                          : () {
                              final dossier = LifecycleBoardExportService.buildRadarDossierText(
                                context: context,
                                items: filteredItems,
                                allImportFiles: allImportFiles,
                              );
                              CopyHelper.copy(context, dossier, customMessage: l10n.lifecycleCopyDossierSuccess);
                            },
                      icon: const Icon(Icons.content_copy_outlined, size: 14, color: AppTheme.cobalt),
                      label: Text(l10n.lifecycleCopyDossierBtn, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // LOWER: Interactive Live Logistics Radar Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: filteredItems.isEmpty
                      ? _buildEmptyState()
                      : _buildRadarDataTable(filteredItems, l10n, allImportFiles),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isAlert ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAlert ? color.withValues(alpha: 0.4) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.0, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskFilterChip(String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedRiskFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 11.0, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : color)),
      selectedColor: color,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: isSelected ? color : (isDark ? AppTheme.darkBorder : color.withValues(alpha: 0.3)))),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _selectedRiskFilter = value),
    );
  }

  Widget _buildRadarDataTable(List<LiveLogisticsTrackingItemModel> items, AppLocalizations l10n, List<ImportFileModel> allImportFiles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _radarVerticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _radarVerticalScrollController,
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _radarHorizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04)),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    columns: [
                      DataColumn(label: Text(l10n.operationalTsvHeaderShipmentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colVesselAndBl, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colEtaCountdown, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colDemurrageRisk, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colSampleTesting, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colDocReadiness, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colQuickActions, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                    ],
                    rows: items.map((item) {
                      Color riskColor = AppTheme.emerald;
                      if (item.demurrageRiskLevel == 'Critical') {
                        riskColor = AppTheme.crimson;
                      } else if (item.demurrageRiskLevel == 'High' || item.demurrageRiskLevel == 'Medium') {
                        riskColor = AppTheme.orange;
                      } else if (item.demurrageRiskLevel == 'Unknown') {
                        riskColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption;
                      }

                      Color sampleColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption;
                      if (item.sampleTestStatus == 'Under Testing') {
                        sampleColor = AppTheme.orange;
                      } else if (item.sampleTestStatus == 'Approved') {
                        sampleColor = AppTheme.emerald;
                      } else if (item.sampleTestStatus == 'Rejected') {
                        sampleColor = AppTheme.crimson;
                      }

                      Color docColor = AppTheme.emerald;
                      if (item.docReadinessPercent < 50.0) {
                        docColor = AppTheme.crimson;
                      } else if (item.docReadinessPercent < 80.0) {
                        docColor = AppTheme.orange;
                      }

                      final isAr = Directionality.of(context) == TextDirection.rtl;
                      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(item.importFileCode, shipments: allImportFiles, isArabic: isAr);
                      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(item.importFileCode, shipments: allImportFiles, isArabic: isAr, includeCodeSecondary: true);

                      final demurrageSummary = item.accumulatedDemurrageFx > 0
                          ? l10n.demurrageIncurredBadge
                          : (item.freeDaysRemaining != null ? l10n.freeDaysRemainingBadge(item.freeDaysRemaining) : '-');
                      final rowSummary = '$shipmentTitle | ${item.companyName} -> ${item.supplierName} | ${item.carrierName ?? l10n.colCarrierUnderPrep} (${item.vesselName ?? "-"}) | ${l10n.colBillOfLadingPrefix}: ${item.blNumber ?? l10n.colCarrierUnderPrep} | ${l10n.colEtaPrefix}: ${item.eta ?? "-"} | $demurrageSummary | ${item.sampleTestStatus} | ${item.docReadinessPercent.toStringAsFixed(0)}%';

                      return DataRow(
                        // CL-005: الضغط على الصف ينتقل لشاشة ملف الاستيراد المقابل
                        onSelectChanged: (selected) {
                          if (selected == true) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImportFilesScreen(
                                  initialSearchQuery: item.importFileCode,
                                  highlightedFileId: item.importFileId,
                                ),
                              ),
                            );
                          }
                        },
                        cells: [
                          // 1. Shipment Name & Code & Importer / Supplier — مع أيقونة التنقل
                          DataCell(
                            CopyableTableCell(
                              value: shipmentTitle,
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    shipmentName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => CopyHelper.copy(context, item.importFileCode),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.darkBorder : AppTheme.charcoal,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              LtrText(
                                                item.importFileCode,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(Icons.copy, size: 9, color: Colors.white70),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // CL-005: أيقونة التنقل للتفاصيل
                                      const Icon(Icons.open_in_new, size: 11, color: AppTheme.cobalt),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.shipmentMode} | ${item.incotermCode}',
                                        style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.companyName} → ${item.supplierName}',
                                    style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. Vessel, Carrier & B/L
                          DataCell(
                            CopyableTableCell(
                              value: '${item.carrierName ?? l10n.colCarrierUnderPrep} - ${item.blNumber ?? l10n.colCarrierUnderPrep}',
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_boat_outlined, size: 12, color: AppTheme.cobalt),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.carrierName ?? l10n.colCarrierUnderPrep} (${item.vesselName ?? "-"})',
                                        style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.colBillOfLadingPrefix}: ${item.blNumber ?? l10n.colCarrierUnderPrep} | ${item.polName ?? "-"} → ${item.podName ?? "-"}',
                                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 3. ETA Countdown & Port Status
                          DataCell(
                            CopyableTableCell(
                              value: '${l10n.colEtaPrefix}: ${item.eta ?? "-"} (${item.arrivalStatus})',
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (item.etaCountdownDays != null && item.etaCountdownDays! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.sailing, size: 11, color: AppTheme.cobalt),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.daysRemainingToEta(item.etaCountdownDays),
                                            style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (item.etaCountdownDays != null && item.etaCountdownDays! <= 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF8E44AD).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.anchor, size: 11, color: Color(0xFF8E44AD)),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.daysInPort(item.etaCountdownDays!.abs()),
                                            style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF8E44AD)),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(item.arrivalStatus, style: TextStyle(fontSize: 11.0, color: Colors.grey.shade700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.colEtaPrefix}: ${item.eta ?? "-"}',
                                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 4. Demurrage & Free Time Radar
                          DataCell(
                            CopyableTableCell(
                              value: item.accumulatedDemurrageFx > 0
                                  ? l10n.demurrageFeesFormatted(item.accumulatedDemurrageFx.toStringAsFixed(0), item.accumulatedDemurrageEgp.toStringAsFixed(0))
                                  : (item.freeDaysTotal != null ? l10n.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal) : '-'),
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: riskColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          item.accumulatedDemurrageFx > 0
                                              ? l10n.demurrageIncurredBadge
                                              : (item.freeDaysRemaining != null ? l10n.freeDaysRemainingBadge(item.freeDaysRemaining) : '-'),
                                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: riskColor),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        item.demurrageRiskLevel == 'Critical'
                                            ? Icons.error
                                            : (item.demurrageRiskLevel == 'Low'
                                                ? Icons.check_circle
                                                : (item.demurrageRiskLevel == 'Unknown' ? Icons.help_outline : Icons.warning_amber)),
                                        size: 13,
                                        color: riskColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.accumulatedDemurrageFx > 0
                                        ? l10n.demurrageFeesFormatted(item.accumulatedDemurrageFx.toStringAsFixed(0), item.accumulatedDemurrageEgp.toStringAsFixed(0))
                                        : (item.freeDaysTotal != null ? l10n.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal) : '-'),
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      fontWeight: item.accumulatedDemurrageFx > 0 ? FontWeight.bold : FontWeight.normal,
                                      color: item.accumulatedDemurrageFx > 0 ? AppTheme.crimson : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 5. Regulatory Testing & Samples
                          DataCell(
                            CopyableTableCell(
                              value: item.sampleTestStatus,
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sampleColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: sampleColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.biotech, size: 11, color: sampleColor),
                                        const SizedBox(width: 3),
                                        Text(
                                          item.sampleTestStatus,
                                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: sampleColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.labReceiptNumber != null ? '${item.regulatoryAgency ?? "GOEIC"} | ${item.labReceiptNumber}' : (item.regulatoryAgency ?? "-"),
                                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 6. Document Readiness & Completeness %
                          DataCell(
                            CopyableTableCell(
                              value: '${item.docReadinessPercent.toStringAsFixed(0)}%',
                              rowSummary: rowSummary,
                              child: Tooltip(
                                message: item.missingDocuments.isEmpty
                                    ? l10n.allDocsCompleted
                                    : '${l10n.missingDocsTooltip}${item.missingDocuments.join(", ")}',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${item.docReadinessPercent.toStringAsFixed(0)}%',
                                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: docColor),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${item.verifiedDocumentsCount}/${item.totalRequiredDocuments})',
                                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    SizedBox(
                                      width: 80,
                                      height: 5,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: item.docReadinessPercent / 100.0,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(docColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 7. Quick Action Launchers
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.timer_outlined, size: 16, color: AppTheme.cobalt),
                                  tooltip: l10n.btnDemurrageSimulator,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (ctx) => const DemurrageDetentionScreen()),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.science_outlined, size: 16, color: AppTheme.orange),
                                  tooltip: l10n.btnRegulatorySamples,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (ctx) => const ImportRequirementsScreen()),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF8E44AD)),
                                  tooltip: l10n.btnCustoms46,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (ctx) => const CustomsDeclaration46Screen()),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.folder_shared_outlined, size: 16, color: AppTheme.charcoal),
                                  tooltip: l10n.btnCentralArchive,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (ctx) => const CentralDocsArchiveScreen()),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.timeline_rounded, size: 16, color: AppTheme.cobalt),
                                  tooltip: isAr ? 'سجل المسار الزمني (25 مرحلة)' : 'Master Timeline Dossier (25 Stages)',
                                  onPressed: () {
                                    ShipmentTimelineDossierDialog.show(
                                      context,
                                      importFileId: item.importFileId,
                                      importFileCode: item.importFileCode,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

  // --- Phase Top Card (Compact Upper 1/3) ------------------------------------

  Widget _buildPhaseTopCard(PhaseSummaryModel phase, double width) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = _parseColor(phase.colorHex);
    final isPhaseSelected = _selectedPhaseId == phase.phaseId && _selectedStepCode == null;

    return Container(
      width: width,
      margin: const EdgeInsetsDirectional.only(end: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPhaseSelected ? headerColor : headerColor.withValues(alpha: 0.35),
          width: isPhaseSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _selectedPhaseId = phase.phaseId;
                _selectedStepCode = null;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(5),
                  topEnd: Radius.circular(5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.lifecyclePhaseName(phase.phaseId, phase.titleAr, phase.titleEn),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${phase.totalActiveShipments}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
            child: Column(
              children: phase.stepCodes.map((stepCode) {
                final count = phase.stepCounts[stepCode] ?? 0;
                final isStepSelected = _selectedStepCode == stepCode;
                final localizedName = l10n.lifecycleStepName(stepCode);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStepCode = stepCode;
                      _selectedPhaseId = phase.phaseId;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: isStepSelected
                          ? headerColor.withValues(alpha: 0.18)
                          : count > 0
                              ? (isDark ? AppTheme.darkSurface : Colors.grey.shade50)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isStepSelected
                            ? headerColor
                            : count > 0
                                ? (isDark ? AppTheme.darkBorder : Colors.grey.shade300)
                                : Colors.transparent,
                        width: isStepSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isStepSelected ? Icons.check_circle : (count > 0 ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                          size: 11,
                          color: isStepSelected
                              ? headerColor
                              : (count > 0 ? headerColor : Colors.grey.shade400),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            localizedName,
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: isStepSelected || count > 0 ? FontWeight.bold : FontWeight.w500,
                              color: isStepSelected ? headerColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: count > 0 ? headerColor.withValues(alpha: 0.2) : (isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: count > 0 ? headerColor : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Table Top Filter Bar --------------------------------------------------

  Widget _buildTableTopBar(List<ShipmentStageCardModel> filteredShipments, List<PhaseSummaryModel> phases, List<ImportFileModel> allImportFiles) {
    final l10n = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final filteredCount = filteredShipments.length;
    String selectedTitle = l10n.allShipmentsAllPhases;
    Color badgeColor = AppTheme.cobalt;

    if (_selectedStepCode != null) {
      final cleanStepName = DisplayNameResolver.resolveStepName(_selectedStepCode!, isArabic: isAr);
      selectedTitle = isAr ? '$cleanStepName (${_selectedStepCode!})' : '$cleanStepName (${_selectedStepCode!})';
      final phaseStr = _stepPhases[_selectedStepCode!];
      final phaseId = int.tryParse(phaseStr ?? '1') ?? 1;
      final p = phases.firstWhere((ph) => ph.phaseId == phaseId, orElse: () => phases[0]);
      badgeColor = _parseColor(p.colorHex);
    } else if (_selectedPhaseId != null) {
      final p = phases.firstWhere((ph) => ph.phaseId == _selectedPhaseId, orElse: () => phases[0]);
      selectedTitle = l10n.lifecyclePhaseName(p.phaseId, p.titleAr, p.titleEn);
      badgeColor = _parseColor(p.colorHex);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
        borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(7), topEnd: Radius.circular(7)),
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                selectedTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.shipmentsCountFormatted(filteredCount),
                style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 12),

            // Kanban Export Toolbar
            OutlinedButton.icon(
              onPressed: filteredShipments.isEmpty
                  ? null
                  : () => LifecycleBoardExportService.exportKanbanToTsv(
                        context: context,
                        shipments: filteredShipments,
                        allImportFiles: allImportFiles,
                        filterTitle: selectedTitle,
                      ),
              icon: Icon(Icons.table_chart_outlined, size: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              label: Text(l10n.lifecycleExportTsvBtn, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: filteredShipments.isEmpty
                  ? null
                  : () => LifecycleBoardExportService.exportKanbanToExcel(
                        context: context,
                        shipments: filteredShipments,
                        allImportFiles: allImportFiles,
                        filterTitle: selectedTitle,
                      ),
              icon: const Icon(Icons.file_download_outlined, size: 14, color: AppTheme.emerald),
              label: Text(l10n.lifecycleExportExcelBtn, style: const TextStyle(fontSize: 11, color: AppTheme.emerald)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: filteredShipments.isEmpty
                  ? null
                  : () => LifecycleBoardExportService.printOrSaveKanbanPdf(
                        context: context,
                        shipments: filteredShipments,
                        phases: phases,
                        allImportFiles: allImportFiles,
                        filterTitle: selectedTitle,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.crimson),
              label: Text(l10n.lifecyclePrintPdfBtn, style: const TextStyle(fontSize: 11, color: AppTheme.crimson)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: filteredShipments.isEmpty
                  ? null
                  : () {
                      final dossier = LifecycleBoardExportService.buildKanbanDossierText(
                        context: context,
                        shipments: filteredShipments,
                        phases: phases,
                        allImportFiles: allImportFiles,
                        filterTitle: selectedTitle,
                      );
                      CopyHelper.copy(context, dossier, customMessage: l10n.lifecycleCopyDossierSuccess);
                    },
              icon: const Icon(Icons.content_copy_outlined, size: 14, color: AppTheme.cobalt),
              label: Text(l10n.lifecycleCopyDossierBtn, style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 220,
              height: 32,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, val, _) {
                  return TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    decoration: InputDecoration(
                      hintText: l10n.searchLifecycleTableHint,
                      hintStyle: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, size: 14, color: AppTheme.cobalt),
                      suffixIcon: val.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Shipments Table -------------------------------------------------------

  Widget _buildShipmentsTable(List<ShipmentStageCardModel> shipments, List<PhaseSummaryModel> phases, List<ImportFileModel> allImportFiles) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 34,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04)),
                    columnSpacing: 14,
                    horizontalMargin: 10,
                    columns: [
                      DataColumn(label: Text(l10n.operationalTsvHeaderShipmentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colPreviousStep, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colCurrentStep, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colNextStep, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colImportCompany, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colForeignSupplier, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colPurchaseOrder, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colModeAndIncoterm, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colEstimatedValue, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colNotesAndActivities, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                      DataColumn(label: Text(l10n.colActionsAndAdvance, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                    ],
                    rows: shipments.map((s) {
                      final phaseStr = _stepPhases[s.stepCode] ?? '1';
                      final phaseId = int.tryParse(phaseStr) ?? 1;
                      final p = phases.firstWhere((ph) => ph.phaseId == phaseId, orElse: () => phases[0]);
                      final stepColor = _parseColor(p.colorHex);
                      final isOnHold = s.status == 'On-Hold';

                      final isAr = Directionality.of(context) == TextDirection.rtl;
                      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(s.importFileCode, shipments: allImportFiles, isArabic: isAr);
                      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(s.importFileCode, shipments: allImportFiles, isArabic: isAr, includeCodeSecondary: true);
                      final cleanCurStep = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
                      final cleanPrevStep = s.previousStepCode != null ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr) : '-';
                      final cleanNextStep = s.nextStepCode != null ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr) : '-';
                      final estCostStr = s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : '—';
                      final estCurrStr = s.estimatedCostCurrency ?? '';
                      final rowSummary = '$shipmentTitle | ${s.companyName} | ${s.supplierName} | $cleanCurStep | ${s.shipmentMode ?? "-"} - ${s.incotermCode ?? "-"} | $estCostStr $estCurrStr${isOnHold ? " (${l10n.onHoldStatusTag})" : ""}';

                      return DataRow(
                        cells: [
                          DataCell(
                            CopyableTableCell(
                              value: shipmentTitle,
                              rowSummary: rowSummary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    shipmentName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => CopyHelper.copy(context, s.importFileCode),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppTheme.darkBorder : AppTheme.charcoal,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              LtrText(
                                                s.importFileCode,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(Icons.copy_rounded, size: 9, color: Colors.white70),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isOnHold) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.crimson,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            l10n.onHoldStatusTag,
                                            style: const TextStyle(color: Colors.white, fontSize: 11.0, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: cleanPrevStep,
                              rowSummary: rowSummary,
                              child: Text(
                                cleanPrevStep,
                                style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: cleanCurStep,
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOnHold ? AppTheme.crimson.withValues(alpha: 0.12) : stepColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isOnHold ? AppTheme.crimson : stepColor, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isOnHold ? Icons.pause_circle_outline : Icons.play_circle_fill, size: 11, color: isOnHold ? AppTheme.crimson : stepColor),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        cleanCurStep,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.0,
                                          color: isOnHold ? AppTheme.crimson : stepColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: cleanNextStep,
                              rowSummary: rowSummary,
                              child: Text(
                                cleanNextStep,
                                style: const TextStyle(fontSize: 11.0, color: AppTheme.cobalt, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: s.companyName,
                              rowSummary: rowSummary,
                              child: Text(s.companyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: s.supplierName,
                              rowSummary: rowSummary,
                              child: Text(s.supplierName, style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: s.poNumber ?? l10n.notSpecifiedOption,
                              rowSummary: rowSummary,
                              child: Text(s.poNumber ?? l10n.notSpecifiedOption, style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
                              rowSummary: rowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: s.estimatedCost != null
                                  ? '${s.estimatedCost!.toStringAsFixed(0)} ${s.estimatedCostCurrency ?? ""}'.trim()
                                  : '—',
                              rowSummary: rowSummary,
                              child: Text(
                                s.estimatedCost != null
                                    ? '${s.estimatedCost!.toStringAsFixed(0)} ${s.estimatedCostCurrency ?? ""}'.trim()
                                    : '—',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s.estimatedCost != null
                                      ? AppTheme.emerald
                                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            CopyableTableCell(
                              value: s.localizedNotes(l10n) ?? l10n.notesUnderFollowupFallback,
                              rowSummary: rowSummary,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  s.localizedNotes(l10n) ?? l10n.notesUnderFollowupFallback,
                                  style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.timeline_rounded, size: 16, color: AppTheme.cobalt),
                                  tooltip: isAr ? 'سجل المسار الزمني (25 مرحلة)' : 'Master Timeline Dossier (25 Stages)',
                                  onPressed: () {
                                    final matchedFile = allImportFiles
                                        .where((f) => f.importFileCode == s.importFileCode)
                                        .firstOrNull;
                                    if (matchedFile != null) {
                                      ShipmentTimelineDossierDialog.show(
                                        context,
                                        importFileId: matchedFile.importFileId,
                                        importFileCode: s.importFileCode,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: stepColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => StepActionDialog(
                                        shipment: s,
                                        allPhases: phases,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.play_circle_outline, size: 13, color: Colors.white),
                                  label: Text(
                                    l10n.executeAndAdvanceStepBtn,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

  Widget _buildEmptyState() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              l10n.noShipmentsInStage,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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

  bool _isStepInPhase(String stepCode, int phaseId, List<PhaseSummaryModel> phases) {
    try {
      final p = phases.firstWhere((ph) => ph.phaseId == phaseId);
      return p.stepCodes.contains(stepCode);
    } catch (_) {
      return false;
    }
  }

  Color _parseColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
