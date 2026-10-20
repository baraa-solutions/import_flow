import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/directional_icon.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_layout_builder.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/widgets/close_shipment_dialog.dart';
import '../../import_files/widgets/shipment_milestone_tracker.dart';
import '../../lifecycle_board/models/lifecycle_board_model.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../shipment_updates/widgets/shipment_update_dialog.dart';
import '../../smart_tasks/models/smart_task_model.dart';
import '../../smart_tasks/providers/smart_tasks_provider.dart';
import '../providers/operational_dashboard_provider.dart';
import '../services/operational_dashboard_export_service.dart';
import '../widgets/container_demurrage_radar_card.dart';
import '../widgets/dashboard_card_drilldown_dialog.dart';

class OperationalDashboardScreen extends ConsumerStatefulWidget {
  const OperationalDashboardScreen({super.key});

  @override
  ConsumerState<OperationalDashboardScreen> createState() => _OperationalDashboardScreenState();
}

class _OperationalDashboardScreenState extends ConsumerState<OperationalDashboardScreen> with DisposeTrackerMixin<OperationalDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _lifecyclePhases = [
    {
      'phase_id': 1,
      'name_ar': 'المرحلة 1: التخطيط والدراسات',
      'name_en': 'Phase 1: Planning & Studies',
      'color': Color(0xFF2980B9),
      'steps': [
        {'code': 'STEP_01', 'name_ar': 'دراسات ومفاضلة النولون', 'name_en': 'Freight Studies'},
        {'code': 'STEP_02', 'name_ar': 'الدراسات والاستشارات الجمركية', 'name_en': 'Customs Studies'},
        {'code': 'STEP_03', 'name_ar': 'اشتراطات ومتطلبات الاستيراد', 'name_en': 'Import Requirements'},
      ],
    },
    {
      'phase_id': 2,
      'name_ar': 'المرحلة 2: الاعتمادات ونافذة التسجيل المسبق',
      'name_en': 'Phase 2: Approvals & ACID',
      'color': Color(0xFF27AE60),
      'steps': [
        {'code': 'STEP_04', 'name_ar': 'اعتماد الميزانية وصرف الدفعة', 'name_en': 'Budget Approval'},
        {'code': 'STEP_05', 'name_ar': 'إصدار رقم التسجيل المسبق نافذة', 'name_en': 'Nafeza ACID Issue'},
      ],
    },
    {
      'phase_id': 3,
      'name_ar': 'المرحلة 3: الحجز وتدقيق المستندات',
      'name_en': 'Phase 3: Booking & Docs',
      'color': Color(0xFFE67E22),
      'steps': [
        {'code': 'STEP_06', 'name_ar': 'تأكيد الحجز الملاحي', 'name_en': 'Booking Confirmation'},
        {'code': 'STEP_07', 'name_ar': 'تخصيص وتوزيع الحاويات والبضائع', 'name_en': 'Container Allocation'},
        {'code': 'STEP_08_PO', 'name_ar': 'مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء', 'name_en': 'PO & Packing Reconciliation'},
        {'code': 'STEP_08_BL', 'name_ar': 'مراجعة مسودة بوليصة الشحن (B/L)', 'name_en': 'Draft B/L Review & Approval'},
        {'code': 'STEP_08_MATCH', 'name_ar': 'المطابقة الذكية بين الفاتورة والبوليصة', 'name_en': 'Smart Invoice vs B/L Match'},
        {'code': 'STEP_08_COO', 'name_ar': 'مسودة شهادة المنشأ و EUR.1', 'name_en': 'Draft COO & EUR.1 Review'},
        {'code': 'STEP_08_COC', 'name_ar': 'شهادات الفحص والتفتيش والمطابقة (COC)', 'name_en': 'Inspection Review & COC'},
        {'code': 'STEP_09', 'name_ar': 'مركز اعتماد المستندات وتعديلات المورد', 'name_en': 'Docs Customs Approval Hub'},
      ],
    },
    {
      'phase_id': 4,
      'name_ar': 'المرحلة 4: التوثيق الإلكتروني والنموذج البنكي',
      'name_en': 'Phase 4: CargoX & Banking',
      'color': Color(0xFF8E44AD),
      'steps': [
        {'code': 'STEP_10', 'name_ar': 'رفع التوثيق الإلكتروني للشاحن', 'name_en': 'CargoX Upload'},
        {'code': 'STEP_11', 'name_ar': 'استلام وتدقيق أصول المستندات', 'name_en': 'Original Docs'},
        {'code': 'STEP_12', 'name_ar': 'استخراج نموذج 4 البنكي', 'name_en': 'Bank Form 4'},
      ],
    },
    {
      'phase_id': 5,
      'name_ar': 'المرحلة 5: التخليص الجمركي والإفراج',
      'name_en': 'Phase 5: Clearance & Release',
      'color': Color(0xFFC0392B),
      'steps': [
        {'code': 'STEP_13', 'name_ar': 'قيد إقرار 46 ك.م جمركي', 'name_en': 'Form 46 KM'},
        {'code': 'STEP_14', 'name_ar': 'الكشف والمعاينة والتثمين', 'name_en': 'Inspection & Valuation'},
        {'code': 'STEP_15', 'name_ar': 'سحب العينات للجهات الرقابية', 'name_en': 'Sample Drawing'},
        {'code': 'STEP_16', 'name_ar': 'تحرير محضر المعاينة الجمركية', 'name_en': 'Inspection Report'},
        {'code': 'STEP_17', 'name_ar': 'سداد الضرائب والرسوم الجمركية', 'name_en': 'Duty Payment'},
        {'code': 'STEP_18', 'name_ar': 'تسوية الأرضيات والحراسات', 'name_en': 'Demurrage & Guard'},
      ],
    },
    {
      'phase_id': 6,
      'name_ar': 'المرحلة 6: المخازن والتسوية النهائية',
      'name_en': 'Phase 6: Storage & Settlement',
      'color': Color(0xFF16A085),
      'steps': [
        {'code': 'STEP_19', 'name_ar': 'إذن إضافة المخازن', 'name_en': 'Warehouse GRN'},
        {'code': 'STEP_20', 'name_ar': 'تسوية تكلفة الاستيراد الشاملة', 'name_en': 'Landed Cost Settlement'},
        {'code': 'STEP_21', 'name_ar': 'إغلاق وأرشفة الملف نهائياً', 'name_en': 'File Archive & Close'},
      ],
    },
  ];

  static const List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];


  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(operationalDashboardProvider);
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(smartTasksProvider);
      ref.invalidate(shipmentUpdatesProvider);
      ref.read(operationalDashboardProvider.notifier).fetchDashboard();
      ref.read(smartTasksProvider.notifier).fetchTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getPriorityLabel(String p, AppLocalizations l) {
    switch (p) {
      case 'All':
        return l.priorityAll;
      case 'Low':
        return l.priorityLow;
      case 'Medium':
        return l.priorityMedium;
      case 'High':
        return l.priorityHigh;
      case 'Critical':
        return l.priorityCritical;
      default:
        return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(operationalDashboardProvider);
    final boardAsync = ref.watch(lifecycleBoardSummaryProvider);
    final notifier = ref.read(operationalDashboardProvider.notifier);
    final density = ref.watch(displayDensityProvider);
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);

    // Memoize / pre-group open tasks by importFileId once per build (O(N) instead of O(N*M))
    final Map<int, List<SmartTaskModel>> openTasksByFileId = {};
    for (final t in tasksState.tasks) {
      if (t.importFileId != null && t.status != 'Completed') {
        (openTasksByFileId[t.importFileId!] ??= []).add(t);
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        title: l.operationalDashboardTitle,
        icon: Icons.dashboard_customize,
        iconColor: AppTheme.cobalt,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: density.buttonIconSize),
            tooltip: l.refresh,
            onPressed: () {
              ref.invalidate(operationalDashboardProvider);
              ref.invalidate(lifecycleBoardSummaryProvider);
              ref.invalidate(smartTasksProvider);
              ref.invalidate(shipmentUpdatesProvider);
              ref.read(operationalDashboardProvider.notifier).fetchDashboard();
              ref.read(smartTasksProvider.notifier).fetchTasks();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  context.isMobile ? 12.0 : 20.0,
                  context.isMobile ? 12.0 : 20.0,
                  context.isMobile ? 12.0 : 20.0,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0. Executive KPI Summary Cards & Risk Alerts
                    dashboardState.data.when(
                      loading: () => const DashboardKpiShimmerSkeleton(),
                      error: (_, __) => const SizedBox(),
                      data: (data) => Column(
                        children: [
                          _buildKpiCardsBar(data, density),
                          const SizedBox(height: 16),
                          const ContainerDemurrageRadarCard(),
                          const SizedBox(height: 16),
                          _buildStreamlitLauncherBanner(),
                          const SizedBox(height: 16),
                          _buildQuickActionsBar(),
                          const SizedBox(height: 16),
                          _buildRiskAlertsBanner(data.shipments),
                          const SizedBox(height: 16),
                          _buildDailyCheckinsCard(data.shipments),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // 1. Shipment Lifecycle Operations Board Summary (6 Phases / 25 Steps)
                    _buildLifecycleOperationsBoardSummary(context, ref, boardAsync, dashboardState, notifier),
                    const SizedBox(height: 16),

                    // 2. Control Bar (Priority Button Group, Customs Broker Dropdown & Debounced Search)
                    _buildControlBar(l, dashboardState, notifier, density),
                    const SizedBox(height: 16),

                    // 3. Results Header & Count
                    _buildResultsHeader(l, dashboardState, density),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 4. Virtualized Shipment Cards List / Loading / Error / Empty States
            dashboardState.data.when(
              loading: () => ShipmentListShimmerSkeleton.sliver(count: 3),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildErrorCard(l, notifier),
                ),
              ),
              data: (dashboardData) {
                final shipments = dashboardData.shipments;
                if (shipments.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 40),
                      child: _buildEmptyStateCard(l, notifier),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final s = shipments[idx];
                        final fileTasks = openTasksByFileId[s.importFileId] ?? const [];
                        return _buildShipmentCard(s, isArabic, fileTasks, l);
                      },
                      childCount: shipments.length,
                    ),
                  ),
                );
              },
            ),

            // 5. Mandatory Anti-Overlap Clearance (+72px buffer for floating AI Assistant / launcher)
            const SliverToBoxAdapter(
              child: SizedBox(height: 72),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(AppLocalizations l, OperationalDashboardState dashboardState, OperationalDashboardNotifier notifier, DisplayDensityMode density) {
    final isDark = AppTheme.isDark(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: density.cardPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Priority Button Group (Scrollable if constrained on mobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.priority, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ToggleButtons(
                        isSelected: _priorities.map((p) => dashboardState.selectedPriority == p).toList(),
                        onPressed: (index) => notifier.setPriority(_priorities[index]),
                        borderRadius: BorderRadius.circular(6),
                        selectedColor: Colors.white,
                        fillColor: AppTheme.wcagCobalt,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        borderColor: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                        selectedBorderColor: AppTheme.wcagCobalt,
                        constraints: BoxConstraints(
                          minHeight: density.isUltraCompact ? 28 : (density.isCompact ? 32 : 36),
                          minWidth: density.isUltraCompact ? 48 : (density.isCompact ? 54 : 60),
                        ),
                        children: _priorities.map((p) => Text(_getPriorityLabel(p, l), style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold))).toList(),
                      ),
                    ),
                  ],
                ),

                // Customs Broker Dynamic Select Dropdown
                dashboardState.data.when(
                  loading: () => SizedBox(
                    width: isCompact ? constraints.maxWidth : 240,
                    child: ShimmerBox(width: 240, height: density.isUltraCompact ? 32 : (density.isCompact ? 36 : 40), borderRadius: 6),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (data) {
                    final brokers = data.availableBrokers;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.customsBrokerLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: isCompact ? constraints.maxWidth : 240,
                          child: SearchableDropdownField<String>(
                            value: dashboardState.selectedBrokerName ?? 'All',
                            labelText: '',
                            items: [
                              SearchableDropdownItem(value: 'All', label: l.allBrokers),
                              ...brokers.map((b) => SearchableDropdownItem(value: b.brokerName, label: b.brokerName)),
                            ],
                            onChanged: (val) => notifier.setBroker(val),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Debounced Search Input (200-300ms)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.quickSearchLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(density.tableHeaderFontSize), color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: isCompact ? constraints.maxWidth : 260,
                      height: density.isUltraCompact ? 30 : (density.isCompact ? 34 : 38),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: density.inputFontSize),
                        decoration: InputDecoration(
                          hintText: l.dashboardSearchHint,
                          hintStyle: TextStyle(fontSize: density.inputFontSize),
                          prefixIcon: Icon(Icons.search, size: density.buttonIconSize),
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) => notifier.setSearchQuery(val),
                      ),
                    ),
                  ],
                ),

                // Reset Filters Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade700,
                    padding: density.buttonPadding,
                    visualDensity: density.visualDensity,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    notifier.resetFilters();
                  },
                  icon: Icon(Icons.restart_alt, size: density.buttonIconSize, color: Colors.white),
                  label: Text(l.resetFilters, style: TextStyle(color: Colors.white, fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize))),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsHeader(AppLocalizations l, OperationalDashboardState dashboardState, DisplayDensityMode density) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return dashboardState.data.maybeWhen(
      data: (dashboardData) {
        final count = dashboardData.shipmentCount;
        final shipments = dashboardData.shipments;
        final dt = DateTime.tryParse(dashboardData.lastUpdatedAt) ?? DateTime.now();
        final lastUpdated = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

        final List<String> activeFilters = [];
        if (dashboardState.selectedPriority != 'All') {
          activeFilters.add('${l.priority} ${_getPriorityLabel(dashboardState.selectedPriority, l)}');
        }
        if (dashboardState.selectedBrokerName != null && dashboardState.selectedBrokerName != 'All') {
          activeFilters.add('${l.customsBrokerLabel} ${dashboardState.selectedBrokerName}');
        }
        if (dashboardState.searchQuery.isNotEmpty) {
          activeFilters.add('${l.quickSearchLabel} "${dashboardState.searchQuery}"');
        }
        if (dashboardState.selectedPhase != null) {
          activeFilters.add('${l.currentPhase}: ${_formatStageName(dashboardState.selectedPhase, isArabic)}');
        }
        final filterSummary = activeFilters.join(' | ');

        final isDark = AppTheme.isDark(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CopyableText(
                  '${l.matchingShipments}: $count ${l.shipmentCountUnit}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.tableHeaderFontSize, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
                Text(
                  '${l.lastUpdated}: $lastUpdated',
                  style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.tableCellSecondaryFontSize), color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 4 Linked Output Actions (TSV, Excel, PDF, Dossier)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.cobalt,
                    side: BorderSide(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.table_view_outlined, size: density.buttonIconSize, color: AppTheme.cobalt),
                  label: Text(l.operationalExportTsvBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.exportTsv(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.emerald,
                    side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.file_present_outlined, size: density.buttonIconSize, color: AppTheme.emerald),
                  label: Text(l.operationalExportExcelBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.exportCsv(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: AppTheme.crimson,
                    side: BorderSide(color: AppTheme.crimson.withValues(alpha: 0.4)),
                  ),
                  icon: Icon(Icons.print_outlined, size: density.buttonIconSize, color: AppTheme.crimson),
                  label: Text(l.operationalExportPdfBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () async {
                          await OperationalDashboardExportService.printPdf(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                            username: 'Sorour Admin',
                          );
                        },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: density.visualDensity,
                    foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    side: BorderSide(color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade400),
                  ),
                  icon: Icon(Icons.copy_all_outlined, size: density.buttonIconSize, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  label: Text(l.operationalCopyDossierBtn, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(density.buttonFontSize), fontWeight: FontWeight.bold)),
                  onPressed: shipments.isEmpty
                      ? null
                      : () {
                          OperationalDashboardExportService.copyDossier(
                            context: context,
                            shipments: shipments,
                            filterSummary: filterSummary,
                          );
                        },
                ),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildErrorCard(AppLocalizations l, OperationalDashboardNotifier notifier) {
    return Card(
      elevation: 1,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.red.shade200)),
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
                  Text('${l.serverConnectionError} (${ApiConstants.serverUrl})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(l.serverConnectionHint, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
              onPressed: () => notifier.fetchDashboard(),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: Text(l.retry, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(AppLocalizations l, OperationalDashboardNotifier notifier) {
    final isDark = AppTheme.isDark(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l.noMatchingShipments, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
            const SizedBox(height: 6),
            Text(l.noMatchingShipmentsDesc, style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
              onPressed: () {
                _searchController.clear();
                notifier.resetFilters();
              },
              child: Text(l.clearFiltersShowAll, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(ImportFileModel s, bool isArabic, List<SmartTaskModel> linkedTasks, AppLocalizations l) {
    final isDark = AppTheme.isDark(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    CopyableText(DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    if (s.customFileNumber != null && s.customFileNumber!.trim().isNotEmpty && s.customFileNumber!.trim() != s.importFileCode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.wcagCobalt.withValues(alpha: isDark ? 0.25 : 0.1), borderRadius: BorderRadius.circular(6)),
                        child: CopyableText(s.importFileCode, textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt)),
                      ),
                    CopyableText(s.companyName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade800)),
                    CopyableText('${DirectionalArrow.symbolForArabic(isArabic)} ${s.supplierName}', style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPriorityBadge(s.priority, l),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.wcagCobalt),
                      tooltip: l.copyTooltip,
                      onPressed: () {
                        final shipmentTitle = DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic, includeCodeSecondary: true);
                        final arrow = DirectionalArrow.symbolForArabic(isArabic);
                        final text = '$shipmentTitle | ${s.companyName} $arrow ${s.supplierName} | ${_formatStageName(s.displayStepKey, isArabic)}';
                        CopyHelper.copy(context, text);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final isNarrow = cardConstraints.maxWidth < 520;
                final phaseColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText('${l.currentPhase}: ${_formatStageName(s.displayStepKey, isArabic)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null)),
                    CopyableText('${l.operationalStep}: ${s.displayStage(l, (t) => _formatStageName(t, isArabic))}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                  ],
                );
                final brokerColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText('${l.customsBrokerLabel} ${s.brokerName ?? l.unassigned}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null)),
                    CopyableText('${l.purchaseOrder} ${s.poNumber ?? l.unassigned}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                  ],
                );
                final progressColumn = Column(
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    CopyableText('${s.progressPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagEmerald, fontSize: 14)),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(value: s.progressPercent / 100.0, backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200, color: AppTheme.wcagEmerald),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: phaseColumn),
                          progressColumn,
                        ],
                      ),
                      const SizedBox(height: 8),
                      brokerColumn,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: phaseColumn),
                    Expanded(child: brokerColumn),
                    progressColumn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // 3-Way Stage Pathway: Previous -> Current -> Next (Responsive & RTL mirrored)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              child: LayoutBuilder(
                builder: (context, pathwayConstraints) {
                  final isCompactPathway = pathwayConstraints.maxWidth < 620;

                  final prevStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: AppTheme.wcagEmerald),
                        const SizedBox(width: 4),
                        CopyableText(
                          s.currentModule.contains('STEP_02') || s.currentModule.contains('Customs') || s.currentModule.contains('جمرك')
                              ? l.pathwayPrevFreightStudies
                              : l.pathwayPrevFilePlanning,
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  );

                  final currentStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.25) : AppTheme.wcagCobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 13, color: AppTheme.wcagCobalt),
                        const SizedBox(width: 4),
                        CopyableText(
                          '${l.pathwayCurrent}: ${_formatStageName(s.displayStepKey, isArabic)}',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt),
                        ),
                      ],
                    ),
                  );

                  final nextStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade700.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isArabic ? Icons.arrow_circle_left_outlined : Icons.arrow_circle_right_outlined, size: 13, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Flexible(
                          child: CopyableText(
                            '${l.pathwayNext}: ${s.renderedNextAction(l) ?? (s.nextAction.isNotEmpty ? _formatActionName(s.nextAction, s.currentModule, isArabic) : l.pathwayNextImportReqs)}',
                            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isCompactPathway) {
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        prevStepWidget,
                        const DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagCobalt),
                        currentStepWidget,
                        const DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagOrange),
                        nextStepWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      prevStepWidget,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagCobalt),
                      ),
                      currentStepWidget,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagOrange),
                      ),
                      Expanded(
                        child: nextStepWidget,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Milestone Progress Tracker (Feature 2.6)
            ShipmentMilestoneTracker(importFile: s),

            // 🎯 Next Step & Target Action Card
            _buildNextStepCard(s, isArabic, l),

            // 📋 Linked Smart Tasks TO-DO List
            _buildLinkedTasksSection(s, linkedTasks, l),

            if (s.status == 'Closed' || s.closureReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppTheme.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CopyableText(
                        '🚫 ${l.closedShipment} [${_formatStageName(s.closedAtPhase ?? s.displayStepKey, isArabic)}] — ${s.closureReason ?? s.displayStage(l, (t) => _formatStageName(t, isArabic))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                    side: BorderSide(color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.post_add_rounded, size: 14),
                  label: Text(l.recordDailyUpdate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => ShipmentUpdateDialog.show(
                    context,
                    initialFileId: s.importFileId,
                    initialFileCode: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
                    initialTargetPhase: s.currentModule,
                  ),
                ),
                if (s.status != 'Closed') ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                      side: BorderSide(color: isDark ? AppTheme.wcagOrange : AppTheme.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.fast_forward_rounded, size: 14),
                    label: Text(l.skipStepBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => SkipStepDialogHelper.show(
                      context: context,
                      ref: ref,
                      importFileCode: s.importFileCode,
                      currentStepCode: s.currentStepCode ?? s.currentStage,
                      currentStepName: _formatStageName(s.displayStepKey, isArabic),
                      onSuccess: () => ref.read(operationalDashboardProvider.notifier).fetchDashboard(),
                    ),
                  ),
                ],
                if (s.status != 'Closed')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.white),
                    label: Text(l.closeStopShipment, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final closed = await showDialog<bool>(
                        context: context,
                        builder: (c) => CloseShipmentDialog(
                          importFileId: s.importFileId,
                          importFileCode: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
                          currentPhaseName: s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic),
                        ),
                      );
                      if (closed == true) {
                        ref.read(operationalDashboardProvider.notifier).fetchDashboard();
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepCard(ImportFileModel s, bool isArabic, AppLocalizations l) {
    if (s.status == 'Closed') return const SizedBox.shrink();

    String nextStepTitle = l.nextStepDefaultTitle;
    String nextStepDesc = l.nextStepDefaultDesc;
    String responsible = l.responsibleImportTeam;
    int targetNavIndex = 1;
    IconData actionIcon = Icons.arrow_forward;

    final mod = '${s.currentStepCode ?? ''} ${s.currentModule}';
    final stg = s.currentStage.toString();
    if (mod.contains('STEP_07') || mod.contains('تخصيص') || mod.contains('Container Allocation')) {
      nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
      nextStepDesc = isArabic
          ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
          : 'Complete VGM container weights and review B/L drafts for CargoX processing';
      responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
      targetNavIndex = 25;
      actionIcon = Icons.rule_folder_outlined;
    } else if (mod.contains('STEP_02') || mod.contains('الدراسات والاستشارات الجمركية') || mod.contains('Customs Studies') || mod.contains('BP-002')) {
      nextStepTitle = l.nextStepImportReqsTitle;
      nextStepDesc = l.nextStepImportReqsDesc;
      responsible = l.responsibleImportSpecialist;
      targetNavIndex = 23;
      actionIcon = Icons.fact_check_outlined;
    } else if (mod.contains('STEP_01') || mod.contains('دراسات ومفاضلة نولون') || mod.contains('Freight Studies')) {
      nextStepTitle = l.nextStepCustomsConsultTitle;
      nextStepDesc = l.nextStepCustomsConsultDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 23;
      actionIcon = Icons.calculate_outlined;
    } else if (mod.contains('Phase 1') || stg.contains('Phase 1') || mod.contains('BP-001') || mod.contains('BP-007')) {
      nextStepTitle = l.nextStepFinanceApprovalTitle;
      nextStepDesc = l.nextStepFinanceApprovalDesc;
      responsible = l.responsibleFinanceDept;
      targetNavIndex = 8;
      actionIcon = Icons.monetization_on_outlined;
    } else if (mod.contains('Phase 2') || stg.contains('Phase 2') || mod.contains('BP-012')) {
      if (s.acidNumber != null && s.acidNumber!.trim().isNotEmpty) {
        if (s.selectedScenario != null && s.selectedScenario!.trim().isNotEmpty) {
          nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
          nextStepDesc = isArabic
              ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
              : 'Complete VGM container weights and review B/L drafts for CargoX processing';
          responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
          targetNavIndex = 25;
          actionIcon = Icons.rule_folder_outlined;
        } else {
          nextStepTitle = l.nextStepFreightBookingTitle;
          nextStepDesc = l.nextStepFreightBookingDesc;
          responsible = l.responsibleFreightForwarder;
          targetNavIndex = 25;
          actionIcon = Icons.directions_boat_outlined;
        }
      } else {
        nextStepTitle = l.nextStepNafezaAcidTitle;
        nextStepDesc = l.nextStepNafezaAcidDesc;
        responsible = l.responsibleNafezaSpecialist;
        targetNavIndex = 11;
        actionIcon = Icons.description_outlined;
      }
    } else if (mod.contains('STEP_08_PO')) {
      nextStepTitle = isArabic ? 'مطابقة الفاتورة والباكينج مع أمر الشراء' : 'PO & Packing Reconciliation';
      nextStepDesc = isArabic ? 'مراجعة وتدقيق بنود الفاتورة والباكينج واستخراج الفروق' : 'Audit commercial invoice and packing list vs PO';
      responsible = isArabic ? 'مسؤول التدقيق المستندي' : 'Documentation Auditor';
      targetNavIndex = 21;
      actionIcon = Icons.fact_check_outlined;
    } else if (mod.contains('STEP_08_BL')) {
      nextStepTitle = isArabic ? 'مراجعة واعتماد مسودة بوليصة الشحن (B/L)' : 'Draft B/L Review & Approval';
      nextStepDesc = isArabic ? 'تدقيق مسودة البوليصة مع الخط الملاحي واعتمادها' : 'Review draft B/L with shipping line and approve';
      responsible = isArabic ? 'مسؤول الشحن والتوثيق' : 'Shipping Specialist';
      targetNavIndex = 18;
      actionIcon = Icons.assignment_turned_in_outlined;
    } else if (mod.contains('STEP_08_MATCH')) {
      nextStepTitle = isArabic ? 'المطابقة الذكية بين الفاتورة والبوليصة' : 'Smart Invoice vs B/L Match';
      nextStepDesc = isArabic ? 'مطابقة حقول الفاتورة النهائية مع بوليصة الشحن' : 'Match commercial invoice fields with draft B/L';
      responsible = isArabic ? 'مسؤول التوثيق' : 'Documentation Specialist';
      targetNavIndex = 22;
      actionIcon = Icons.auto_awesome;
    } else if (mod.contains('STEP_08_COO')) {
      nextStepTitle = isArabic ? 'مراجعة مسودة شهادة المنشأ و EUR.1' : 'Draft COO & EUR.1 Review';
      nextStepDesc = isArabic ? 'تدقيق قواعد المنشأ والاتفاقيات التفضيلية' : 'Audit rules of origin and preferential trade agreements';
      responsible = isArabic ? 'أخصائي الجمارك' : 'Customs Specialist';
      targetNavIndex = 19;
      actionIcon = Icons.flag_circle_outlined;
    } else if (mod.contains('STEP_08_COC')) {
      nextStepTitle = isArabic ? 'شهادات الفحص والتفتيش والمطابقة (COC)' : 'Inspection Review & COC';
      nextStepDesc = isArabic ? 'تدقيق شهادات المطابقة الدولية ومعايير GOEIC' : 'Audit pre-shipment inspection certificates';
      responsible = isArabic ? 'مسؤول المطابقة والجودة' : 'Conformity Specialist';
      targetNavIndex = 53;
      actionIcon = Icons.security_outlined;
    } else if (mod.contains('STEP_09') || mod.contains('BP-009')) {
      nextStepTitle = isArabic ? 'مركز اعتماد المستندات وتعديلات المورد' : 'Docs Customs Approval Hub';
      nextStepDesc = isArabic ? 'الحصول على الاعتماد الجمركي المبدئي وإصدار خطابات التعديل' : 'Obtain customs approval and issue supplier rectification notes';
      responsible = isArabic ? 'المستخلص الجمركي' : 'Customs Broker';
      targetNavIndex = 20;
      actionIcon = Icons.verified_user_outlined;
    } else if (mod.contains('Phase 3') || stg.contains('Phase 3') || mod.contains('BP-015') || mod.contains('BP-019')) {
      if (s.selectedScenario != null && s.selectedScenario!.trim().isNotEmpty) {
        nextStepTitle = isArabic ? 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن' : 'VGM Verification & Shipping Draft Approval';
        nextStepDesc = isArabic
            ? 'استكمال أوزان الحاويات VGM ومراجعة بوالص الشحن وفواتير المورد للتجهيز لمنظومة CargoX'
            : 'Complete VGM container weights and review B/L drafts for CargoX processing';
        responsible = isArabic ? 'مسؤول الشحن والتوثيق الملاحي' : 'Shipping & Documentation Specialist';
        targetNavIndex = 26;
        actionIcon = Icons.rule_folder_outlined;
      } else {
        nextStepTitle = l.nextStepFreightBookingTitle;
        nextStepDesc = l.nextStepFreightBookingDesc;
        responsible = l.responsibleFreightForwarder;
        targetNavIndex = 25;
        actionIcon = Icons.directions_boat_outlined;
      }
    } else if (mod.contains('Phase 4') || stg.contains('Phase 4')) {
      nextStepTitle = l.nextStepTransitTrackingTitle;
      nextStepDesc = l.nextStepTransitTrackingDesc;
      responsible = l.responsibleShippingCarrier;
      targetNavIndex = 26;
      actionIcon = Icons.sailing_outlined;
    } else if (mod.contains('Phase 5')) {
      nextStepTitle = l.nextStepArrivalNoticeTitle;
      nextStepDesc = l.nextStepArrivalNoticeDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 23;
      actionIcon = Icons.receipt_long_outlined;
    } else if (mod.contains('Phase 6')) {
      nextStepTitle = l.nextStepDutyPaymentTitle;
      nextStepDesc = l.nextStepDutyPaymentDesc;
      responsible = l.responsibleCustomsBroker;
      targetNavIndex = 27;
      actionIcon = Icons.verified_user_outlined;
    } else if (mod.contains('Phase 7')) {
      nextStepTitle = l.nextStepInlandTransportTitle;
      nextStepDesc = l.nextStepInlandTransportDesc;
      responsible = l.responsibleWarehouseCustodian;
      targetNavIndex = 28;
      actionIcon = Icons.warehouse_outlined;
    } else if (mod.contains('Phase 8')) {
      nextStepTitle = l.nextStepLandedCostTitle;
      nextStepDesc = l.nextStepLandedCostDesc;
      responsible = l.responsibleFinanceAuditing;
      targetNavIndex = 29;
      actionIcon = Icons.calculate_outlined;
    } else if (mod.contains('Phase 9')) {
      nextStepTitle = l.nextStepClosureTitle;
      nextStepDesc = l.nextStepClosureDesc;
      responsible = l.responsibleImportManager;
      targetNavIndex = 30;
      actionIcon = Icons.archive_outlined;
    }

    final isDark = AppTheme.isDark(context);
    final actionBgColor = isDark ? AppTheme.wcagCobalt : AppTheme.cobalt;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        final button = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionBgColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => selectNavigationIndex(ref, targetNavIndex),
          icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
          label: Text(l.executeStepNow, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        );

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.15) : AppTheme.cobalt.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.4) : AppTheme.cobalt.withValues(alpha: 0.25)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: actionBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(actionIcon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(l.nextStepAction, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CopyableText(
                                  '${l.responsiblePerson}: $responsible',
                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.brown.shade800),
                                  showIcon: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CopyableText(nextStepTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    CopyableText(nextStepDesc, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: actionBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(actionIcon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(l.nextStepAction, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: CopyableText(
                                  '${l.responsiblePerson}: $responsible',
                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.brown.shade800),
                                  showIcon: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          CopyableText(nextStepTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                          CopyableText(nextStepDesc, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    button,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLinkedTasksSection(ImportFileModel s, List<SmartTaskModel> linkedTasks, AppLocalizations l) {
    if (linkedTasks.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 16),
              const SizedBox(width: 6),
              Text('${l.openShipmentTasks} (${linkedTasks.length} ${l.tasksCountUnit}):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => selectNavigationIndex(ref, 40),
                icon: const Icon(Icons.open_in_new, size: 12),
                label: Text(l.manageAllTasks, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...linkedTasks.map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: t.status == 'Completed',
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.emerald,
                    checkColor: Colors.white,
                    side: BorderSide(color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade500),
                    onChanged: (val) async {
                      if (val == true) {
                        try {
                          await ref.read(smartTasksProvider.notifier).updateTask(t.taskId, {'status': 'Completed'});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${l.taskCompletedSuccessfully}: ${t.displayTitle(context.l10n)}'),
                                backgroundColor: AppTheme.emerald,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.crimson,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: CopyableText(
                      t.displayTitle(context.l10n),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade900),
                    ),
                  ),
                  if (t.priority == 'Critical')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_getPriorityLabel(t.priority, l), style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red, fontSize: 11.0, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 8),
                  if (t.dueDate != null && t.dueDate!.trim().isNotEmpty)
                    CopyableText(
                      t.dueDate!,
                      style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600),
                      showIcon: false,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKpiCardsBar(dynamic data, DisplayDensityMode density) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final tasksState = ref.watch(smartTasksProvider);
    final shipments = (data.shipments as List<dynamic>).cast<ImportFileModel>();
    final tasks = tasksState.tasks;

    void onFocusShipment(String shipmentCode) {
      _searchController.text = shipmentCode;
      ref.read(operationalDashboardProvider.notifier).setSearchQuery(shipmentCode);
    }

    void onCompleteTask(int taskId) async {
      try {
        await ref.read(smartTasksProvider.notifier).updateTask(taskId, {'status': 'Completed'});
        ref.read(operationalDashboardProvider.notifier).fetchDashboard();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
      }
    }

    void onDailyUpdate(ImportFileModel shipment) {
      ShipmentUpdateDialog.show(
        context,
        initialFileId: shipment.importFileId,
        initialFileCode: DisplayNameResolver.resolveShipmentTitle(shipment, isArabic: isArabic),
        initialTargetPhase: shipment.currentModule,
      );
    }

    final todaysTasksRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.todaysTasks,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final pendingTasksRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.pendingTasks,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final upcomingShipmentsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.upcomingShipments,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final arrivingThisWeekRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.arrivingThisWeek,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final etaChangesRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.etaChanges,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final waitingForPaymentRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.waitingForPayment,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final waitingForForm4Records = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.waitingForForm4,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final pendingRequirementsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.pendingRequirements,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    final highPriorityAlertsRecords = DashboardDrillDownHelper.getRecords(
      type: DashboardCardType.highPriorityAlerts,
      shipments: shipments,
      tasks: tasks,
      isArabic: isArabic,
      l: l,
      onFocusShipment: onFocusShipment,
      onCompleteTask: onCompleteTask,
      onDailyUpdate: onDailyUpdate,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final double cardWidth;
        if (screenWidth < 480) {
          cardWidth = screenWidth; // 1 column on mobile (<480px)
        } else if (screenWidth < 768) {
          cardWidth = (screenWidth - 12) / 2; // 2 columns on large phone / small tablet
        } else if (screenWidth < 1050) {
          cardWidth = (screenWidth - 24) / 3; // 3 columns on tablet
        } else if (screenWidth < 1350) {
          cardWidth = (screenWidth - 36) / 4; // 4 columns on compact desktop
        } else {
          cardWidth = (screenWidth - 48) / 5; // 5 columns on wide desktop
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiTodaysTasks,
              mainValue: '${todaysTasksRecords.length} ${l.tasksCountUnit}',
              subtitle: l.kpiTodaysTasksSub,
              icon: Icons.today,
              color: AppTheme.wcagCobalt,
              records: todaysTasksRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiTodaysTasks,
                icon: Icons.today,
                themeColor: AppTheme.wcagCobalt,
                records: todaysTasksRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiPendingTasks,
              mainValue: '${pendingTasksRecords.length} ${l.tasksCountUnit}',
              subtitle: l.kpiPendingTasksSub,
              icon: Icons.pending_actions,
              color: AppTheme.wcagOrange,
              records: pendingTasksRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiPendingTasks,
                icon: Icons.pending_actions,
                themeColor: AppTheme.wcagOrange,
                records: pendingTasksRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiUpcomingShipments,
              mainValue: '${upcomingShipmentsRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiUpcomingShipmentsSub,
              icon: Icons.near_me,
              color: AppTheme.wcagEmerald,
              records: upcomingShipmentsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiUpcomingShipments,
                icon: Icons.near_me,
                themeColor: AppTheme.wcagEmerald,
                records: upcomingShipmentsRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiArrivingThisWeek,
              mainValue: '${arrivingThisWeekRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiArrivingThisWeekSub,
              icon: Icons.directions_boat,
              color: AppTheme.wcagCobalt,
              records: arrivingThisWeekRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiArrivingThisWeek,
                icon: Icons.directions_boat,
                themeColor: AppTheme.wcagCobalt,
                records: arrivingThisWeekRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiEtaChanges,
              mainValue: '${etaChangesRecords.length}',
              subtitle: l.kpiEtaChangesSub,
              icon: Icons.edit_calendar,
              color: Colors.purple.shade600,
              records: etaChangesRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiEtaChanges,
                icon: Icons.edit_calendar,
                themeColor: Colors.purple.shade600,
                records: etaChangesRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiWaitingPayment,
              mainValue: '${waitingForPaymentRecords.length}',
              subtitle: l.kpiWaitingPaymentSub,
              icon: Icons.monetization_on,
              color: AppTheme.wcagCrimson,
              records: waitingForPaymentRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiWaitingPayment,
                icon: Icons.monetization_on,
                themeColor: AppTheme.wcagCrimson,
                records: waitingForPaymentRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiWaitingForm4,
              mainValue: '${waitingForForm4Records.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiWaitingForm4Sub,
              icon: Icons.account_balance,
              color: AppTheme.wcagOrange,
              records: waitingForForm4Records,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiWaitingForm4,
                icon: Icons.account_balance,
                themeColor: AppTheme.wcagOrange,
                records: waitingForForm4Records,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiPendingRequirements,
              mainValue: '${pendingRequirementsRecords.length} ${l.shipmentCountUnit}',
              subtitle: l.kpiPendingRequirementsSub,
              icon: Icons.rule,
              color: AppTheme.wcagCrimson,
              records: pendingRequirementsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiPendingRequirements,
                icon: Icons.rule,
                themeColor: AppTheme.wcagCrimson,
                records: pendingRequirementsRecords,
                isArabic: isArabic,
              ),
            ),
            _buildKpiCard(
              density: density,
              cardWidth: cardWidth,
              title: l.kpiHighPriorityAlerts,
              mainValue: '${highPriorityAlertsRecords.length}',
              subtitle: l.kpiHighPriorityAlertsSub,
              icon: Icons.warning_amber,
              color: AppTheme.isDark(context) ? Colors.red.shade400 : AppTheme.wcagCrimson,
              records: highPriorityAlertsRecords,
              clickHint: l.drillDownCardClickHint,
              onTap: () => DashboardCardDrillDownDialog.show(
                context: context,
                title: l.kpiHighPriorityAlerts,
                icon: Icons.warning_amber,
                themeColor: AppTheme.isDark(context) ? Colors.red.shade400 : AppTheme.wcagCrimson,
                records: highPriorityAlertsRecords,
                isArabic: isArabic,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required DisplayDensityMode density,
    required String title,
    required String mainValue,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<DrillDownItem> records,
    required VoidCallback onTap,
    required String clickHint,
    double cardWidth = 220,
  }) {
    final isDark = AppTheme.isDark(context);
    final cardPad = density.isUltraCompact ? 8.0 : (density.isCompact ? 10.0 : 14.0);
    return SizedBox(
      width: cardWidth,
      child: Tooltip(
        message: clickHint,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.all(cardPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(density.metricTitleFontSize),
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(density.isUltraCompact ? 4 : 6),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Icon(icon, color: color, size: density.metricIconSize),
                      ),
                    ],
                  ),

                  SizedBox(height: density.isUltraCompact ? 4 : 8),
                  Row(
                    children: [
                      Expanded(
                        child: CopyableText(
                          mainValue,
                          style: TextStyle(
                            fontSize: DisplayDensityMode.clampFontSize(density.metricValueFontSize),
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          showIcon: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new_rounded, size: density.buttonIconSize - 2, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade400),
                    ],
                  ),
                  SizedBox(height: density.isUltraCompact ? 2 : 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(density.tableCellSecondaryFontSize),
                      color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskAlertsBanner(List<dynamic> shipments) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final isDark = AppTheme.isDark(context);
    final criticals = shipments.where((s) => s.priority == 'Critical' || s.priority == 'High').toList();
    final tasksState = ref.watch(smartTasksProvider);
    final regTasks = tasksState.tasks.where((t) => (t.taskType == 'Regulatory Compliance' || (t.phaseName != null && t.phaseName!.contains('STEP_03'))) && t.status != 'Completed').toList();

    if (criticals.isEmpty && regTasks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? Colors.amber.shade700.withValues(alpha: 0.5) : Colors.amber.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 460;
            final maxChipTextWidth = (constraints.maxWidth - 90).clamp(60.0, 320.0);

            final badgeWidget = regTasks.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B1E22) : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.red.shade700 : Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rule_folder, size: 12, color: AppTheme.crimson),
                        const SizedBox(width: 4),
                        Text(
                          l.pendingRegRequirementsCount(regTasks.length),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : AppTheme.crimson),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.riskAlertsCenter,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (regTasks.isNotEmpty) badgeWidget,
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.orange, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.riskAlertsCenter,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ),
                      const SizedBox(width: 8),
                      badgeWidget,
                    ],
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...regTasks.take(3).map((t) {
                      final title = t.displayTitle(context.l10n);
                      return GestureDetector(
                        onDoubleTap: () => CopyHelper.copy(context, title),
                        onSecondaryTap: () => CopyHelper.copy(context, title),
                        child: Tooltip(
                          message: l.copyTooltip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3B1E22) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 14),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxChipTextWidth),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : AppTheme.crimson),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    ...criticals.take(3).map((s) {
                      final text = '${s.primaryNameWithCode} — ${s.displayStage(context.l10n, (t) => _formatStageName(t, isArabic))}';
                      return GestureDetector(
                        onDoubleTap: () => CopyHelper.copy(context, text),
                        onSecondaryTap: () => CopyHelper.copy(context, text),
                        child: Tooltip(
                          message: l.copyTooltip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? AppTheme.darkBorderLight : Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning, color: AppTheme.orange, size: 14),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxChipTextWidth),
                                  child: Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatStageName(String? stage, bool isArabic) {
    if (stage == null || stage.trim().isEmpty) return '';
    final s = stage.trim();

    if (s.toUpperCase().startsWith('STEP_') || s.toLowerCase().startsWith('step')) {
      return DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    }
    if (s.toLowerCase().contains('phase') || s.contains('المرحلة') || s.toUpperCase().startsWith('P')) {
      return DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    }

    final step = DisplayNameResolver.resolveStepName(s, isArabic: isArabic);
    if (step != s && step != '-') return step;

    final phase = DisplayNameResolver.resolvePhaseName(s, isArabic: isArabic);
    if (phase != s && phase != '-') return phase;

    return s;
  }

  String _formatActionName(String nextAction, String currentModule, bool isArabic) {
    final action = DisplayNameResolver.resolveActionTitle(nextAction, isArabic: isArabic);
    final current = _formatStageName(currentModule, isArabic);
    if (action.trim().toLowerCase() == current.trim().toLowerCase()) {
      if (currentModule.contains('STEP_07') || currentModule.contains('Container') || currentModule.contains('تخصيص')) {
        return isArabic ? 'مراجعة واعتماد مسودات مستندات الشحن' : 'Review & Approve Shipping Drafts';
      }
      if (currentModule.contains('STEP_01') || currentModule.contains('Freight') || currentModule.contains('نولون')) {
        return isArabic ? 'الدراسات والاستشارات الجمركية' : 'Customs Studies';
      }
      return isArabic ? 'متابعة الخطوة التشغيلية التالية' : 'Next Operational Step';
    }
    return action;
  }

  Widget _buildPriorityBadge(String priority, AppLocalizations l) {
    final isDark = AppTheme.isDark(context);
    Color bg = isDark ? AppTheme.darkSurface : Colors.grey.shade200;
    Color fg = isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800;
    if (priority == 'High') {
      bg = isDark ? Colors.orange.shade900.withValues(alpha: 0.35) : Colors.orange.shade100;
      fg = isDark ? Colors.orange.shade300 : Colors.orange.shade900;
    } else if (priority == 'Critical') {
      bg = isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade100;
      fg = isDark ? Colors.red.shade300 : Colors.red.shade900;
    } else if (priority == 'Medium') {
      bg = isDark ? Colors.blue.shade900.withValues(alpha: 0.35) : Colors.blue.shade100;
      fg = isDark ? Colors.lightBlueAccent : Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(_getPriorityLabel(priority, l), style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 11)),
    );
  }

  Widget _buildDailyCheckinsCard(List<ImportFileModel> shipments) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final isDark = AppTheme.isDark(context);
    final updatesState = ref.watch(shipmentUpdatesProvider);
    final logs = updatesState.logs;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 460;
            final headerButton = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () => ShipmentUpdateDialog.show(context),
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: Text(l.addDailyUpdate, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          children: [
                            Icon(Icons.published_with_changes, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l.dailyCheckinsLog, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            ),
                          ],
                        ),
                      ),
                      headerButton,
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.published_with_changes, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.dailyCheckinsLog, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                      ),
                      const SizedBox(width: 8),
                      headerButton,
                    ],
                  ),
                const SizedBox(height: 10),
                if (logs.isEmpty)
                  Text(l.noDailyUpdates, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : Colors.grey))
                else
                  LayoutBuilder(
                builder: (context, constraints) {
                  final double itemWidth = constraints.maxWidth < 280 ? constraints.maxWidth : 260.0;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: logs.take(5).map((log) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        width: itemWidth,
                        decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.white, border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CopyableText(
                                DisplayNameResolver.resolveShipmentTitleByCode(
                                  log.importFileCode,
                                  shipments: shipments,
                                  isArabic: isArabic,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(log.logDate, style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        CopyableText(
                          '${DisplayNameResolver.resolvePhaseName(log.targetPhase, isArabic: isArabic)} — ${DisplayNameResolver.resolveUpdateCategory(log.updateCategory, isArabic: isArabic)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        const SizedBox(height: 4),
                        CopyableText(log.note, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

  // ─── Quick Actions & Registration Shortcuts Bar ───────────────────────────

  Widget _buildQuickActionsBar() {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Smart Extractor Header & Launch Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.amber.shade700.withValues(alpha: 0.5) : Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.aiSmartExtractorTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal, foregroundColor: Colors.white),
                        icon: const Icon(Icons.public, size: 16),
                        label: Text(l.smartExtractSupplier),
                        onPressed: () => UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.supplier),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                        icon: const Icon(Icons.domain, size: 16),
                        label: Text(l.smartExtractCompany),
                        onPressed: () => UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.company),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                        icon: const Icon(Icons.handshake, size: 16),
                        label: Text(l.smartExtractPartner),
                        onPressed: () => UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.partner),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                        icon: const Icon(Icons.account_balance, size: 16),
                        label: Text(l.smartExtractBank),
                        onPressed: () => UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.bank),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(Icons.bolt, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.quickShortcutsTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildQuickActionButton(
                  l.createNewProject,
                  Icons.assignment_outlined,
                  isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  () => selectNavigationIndex(ref, 31), // Projects
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewImportFile,
                  Icons.folder_special_outlined,
                  isDark ? Colors.tealAccent : AppTheme.emerald,
                  () => selectNavigationIndex(ref, 1), // Import Files
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewImportCompany,
                  Icons.domain_outlined,
                  isDark ? Colors.amber.shade400 : AppTheme.orange,
                  () => selectNavigationIndex(ref, 32), // Import Companies
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewSupplier,
                  Icons.business_outlined,
                  isDark ? Colors.tealAccent.shade200 : AppTheme.charcoal,
                  () => selectNavigationIndex(ref, 33), // Foreign Suppliers
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewPartnerBank,
                  Icons.account_balance_outlined,
                  isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  () => selectNavigationIndex(ref, 34), // Partners & Banks
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewCustomsTariff,
                  Icons.description_outlined,
                  isDark ? Colors.orange.shade300 : AppTheme.orange,
                  () => selectNavigationIndex(ref, 36), // Customs Tariff
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewLocation,
                  Icons.location_on_outlined,
                  isDark ? Colors.tealAccent : AppTheme.emerald,
                  () => selectNavigationIndex(ref, 37), // Ports & Locations
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewCurrency,
                  Icons.currency_exchange_outlined,
                  isDark ? Colors.purpleAccent.shade100 : AppTheme.charcoal,
                  () => selectNavigationIndex(ref, 38), // Currencies
                  isDark: isDark,
                ),
                _buildQuickActionButton(
                  l.createNewExchangeRate,
                  Icons.rate_review_outlined,
                  isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  () => selectNavigationIndex(ref, 38), // Exchange Rates
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap, {bool isDark = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            DirectionalIcon(Icons.arrow_forward_ios, size: 10, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  // ─── Operations Board Interactive Banner ────────────────────────
  Widget _buildStreamlitLauncherBanner() {
    final l = context.l10n;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.wcagCobalt, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.interactiveOperationsBoardTitle,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.badgeNew,
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.interactiveOperationsBoardDesc,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.wcagCobalt,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => selectNavigationIndex(ref, 48),
                      icon: const Icon(Icons.launch, size: 16, color: Colors.white),
                      label: Text(
                        l.openInteractiveBoard,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.wcagCobalt.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.wcagCobalt, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l.interactiveOperationsBoardTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            l.badgeNew,
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.interactiveOperationsBoardDesc,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.wcagCobalt,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => selectNavigationIndex(ref, 48), // Native Lifecycle Board Screen
                  icon: const Icon(Icons.launch, size: 16, color: Colors.white),
                  label: Text(
                    l.openInteractiveBoard,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================================================================
  // Shipment Lifecycle Operations Board Summary (6 Phases / 25 Steps)
  // =========================================================================
  Widget _buildLifecycleOperationsBoardSummary(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<LifecycleBoardSummaryModel> boardAsync,
    OperationalDashboardState dashboardState,
    OperationalDashboardNotifier notifier,
  ) {
    final l = context.l10n;
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar (Responsive)
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isCompact = headerConstraints.maxWidth < 650;
                final headerInfo = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.view_kanban_outlined, color: AppTheme.wcagCobalt, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.lifecycleBoardSummaryTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                          Text(
                            l.lifecycleBoardSummaryDesc,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dashboardState.selectedPhase != null)
                      OutlinedButton.icon(
                        onPressed: () => notifier.togglePhase(dashboardState.selectedPhase!),
                        icon: const Icon(Icons.clear, size: 14, color: AppTheme.crimson),
                        label: Text('${l.clearFilter} (${_formatStageName(dashboardState.selectedPhase, isArabic)})', style: const TextStyle(color: AppTheme.crimson, fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.crimson),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => selectNavigationIndex(ref, 48),
                      icon: const Icon(Icons.open_in_new, size: 15, color: Colors.white),
                      label: Text(l.fullOperationsBoardButton, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerInfo,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: headerInfo),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // 6 Phases & 25 Steps
            boardAsync.when(
              loading: () => const LifecycleSummaryShimmerSkeleton(),
              error: (_, __) => _buildDynamicLifecyclePhases(null, dashboardState, notifier),
              data: (boardData) => _buildDynamicLifecyclePhases(boardData, dashboardState, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLifecyclePhases(
    LifecycleBoardSummaryModel? boardData,
    OperationalDashboardState dashboardState,
    OperationalDashboardNotifier notifier,
  ) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth < 650) {
          cardWidth = constraints.maxWidth; // 1 column on mobile (<650px)
        } else if (constraints.maxWidth < 1100) {
          cardWidth = (constraints.maxWidth - 12) / 2; // 2 columns on tablet
        } else {
          cardWidth = (constraints.maxWidth - 24) / 3; // 3 columns on desktop
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _lifecyclePhases.map((phaseMeta) {
            final int phaseId = phaseMeta['phase_id'];
            final String phaseName = isArabic ? phaseMeta['name_ar'] : phaseMeta['name_en'];
            final Color phaseColor = phaseMeta['color'];
            final List<Map<String, String>> steps = List<Map<String, String>>.from(phaseMeta['steps']);

            final matchingPhase = boardData?.phases.where((p) => p.phaseId == phaseId).firstOrNull;
            final int phaseActiveCount = matchingPhase?.totalActiveShipments ?? 0;
            final Map<String, int> stepCounts = matchingPhase?.stepCounts ?? {};

            final bool isPhaseSelected = dashboardState.selectedPhase == 'Phase $phaseId' || dashboardState.selectedPhase == 'P$phaseId';

            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPhaseSelected ? phaseColor.withValues(alpha: isDark ? 0.18 : 0.08) : (isDark ? AppTheme.darkCardBackground : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPhaseSelected ? phaseColor : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  width: isPhaseSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase Header
                  InkWell(
                    onTap: () => notifier.togglePhase('Phase $phaseId'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: phaseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    phaseName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isPhaseSelected ? phaseColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: phaseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$phaseActiveCount ${l.shipmentCountUnit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: phaseColor,
                              ),
                            ),
                          ),
                        ],

                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),

                  // Steps Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: steps.map((step) {
                      final String stepCode = step['code']!;
                      final String stepName = isArabic ? (step['name_ar'] ?? step['name'] ?? '') : (step['name_en'] ?? step['name'] ?? '');
                      final int count = stepCounts[stepCode] ?? 0;
                      final bool isStepSelected = dashboardState.selectedPhase == stepCode;

                      return InkWell(
                        onTap: () => notifier.togglePhase(stepCode),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isStepSelected
                                ? phaseColor
                                : (count > 0 ? phaseColor.withValues(alpha: isDark ? 0.22 : 0.12) : (isDark ? AppTheme.darkSurface : Colors.grey.shade100)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isStepSelected
                                  ? phaseColor
                                  : (count > 0 ? phaseColor.withValues(alpha: isDark ? 0.6 : 0.4) : (isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  stepName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isStepSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isStepSelected
                                        ? Colors.white
                                        : (count > 0 ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isStepSelected
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : (count > 0 ? phaseColor : Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

