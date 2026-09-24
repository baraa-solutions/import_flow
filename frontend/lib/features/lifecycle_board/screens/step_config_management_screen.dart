import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/step_config_model.dart';
import '../providers/step_config_provider.dart';
import '../services/step_config_export_service.dart';

class StepConfigManagementScreen extends ConsumerStatefulWidget {
  const StepConfigManagementScreen({super.key});

  @override
  ConsumerState<StepConfigManagementScreen> createState() =>
      _StepConfigManagementScreenState();
}

class _StepConfigManagementScreenState
    extends ConsumerState<StepConfigManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isAuthorized = user?.canManageStepConfig ?? false;

    // Surface backend load errors (e.g. 403 detail) instead of failing silently.
    ref.listen<StepConfigState>(stepConfigProvider, (prev, next) {
      final loadFinished = (prev?.isLoading ?? false) && !next.isLoading;
      if (loadFinished && next.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppTheme.crimson),
        );
      }
    });

    return SelectionArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: !isAuthorized
            ? _buildAccessDeniedView()
            : _buildAuthorizedManagementView(),
      ),
    );
  }

  Widget _buildAccessDeniedView() {
    final l = context.l10n;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 48,
                color: Color(0xFFC0392B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.stepConfigAccessDeniedTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l.stepConfigAccessDeniedDesc,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7F8C8D),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            // Demo role switching is a debug-only development aid.
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to manager role if in demo mode
                  ref.read(authProvider.notifier).switchDemoRole('MANAGER');
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(l.stepConfigDemoSwitchBtn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizedManagementView() {
    final state = ref.watch(stepConfigProvider);
    final notifier = ref.read(stepConfigProvider.notifier);

    return Column(
      children: [
        _buildHeader(notifier),
        _buildFilterBar(state, notifier),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredConfigs.isEmpty
                  ? _buildEmptyView()
                  : _buildTableView(state.filteredConfigs),
        ),
      ],
    );
  }

  Widget _buildHeader(StepConfigNotifier notifier) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.flatCobalt.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppTheme.flatCobalt,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.stepConfigTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.stepConfigSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.stepConfigRefreshTooltip,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2C3E50)),
            onPressed: () => notifier.fetchConfigs(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(StepConfigState state, StepConfigNotifier notifier) {
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 950;

          final searchAndFilters = Row(
            children: [
              // Search box with copy suffix button
              SizedBox(
                width: isNarrow ? 220 : 280,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: notifier.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: l.stepConfigSearchHint,
                    hintStyle: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    size: 15, color: AppTheme.flatCobalt),
                                tooltip: l.stepConfigSearchCopied,
                                onPressed: () {
                                  CopyHelper.copy(
                                    context,
                                    _searchController.text,
                                    customMessage: l.stepConfigSearchCopied,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 15, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                  setState(() {});
                                },
                              ),
                            ],
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Phase Filter Pills
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPhaseFilterChip(
                        label: l.stepConfigPhaseAll,
                        isSelected: state.selectedPhaseFilter == null,
                        onSelected: () => notifier.setFilterPhase(null),
                      ),
                      for (int i = 1; i <= 6; i++) ...[
                        const SizedBox(width: 6),
                        _buildPhaseFilterChip(
                          label: l.stepConfigPhaseLabel(i),
                          isSelected: state.selectedPhaseFilter == i,
                          onSelected: () => notifier.setFilterPhase(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );

          final exportToolbar = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => StepConfigExportService.saveTsvToFile(
                    context, state.filteredConfigs,
                    isArabic: isAr),
                icon: const Icon(Icons.table_view_rounded, size: 16),
                label: Text(l.stepConfigExportTsvBtn,
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C3E50),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => StepConfigExportService.saveCsvToFile(
                    context, state.filteredConfigs,
                    isArabic: isAr),
                icon: const Icon(Icons.description_outlined,
                    size: 16, color: Color(0xFF27AE60)),
                label: Text(l.stepConfigExportExcelBtn,
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF27AE60),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => StepConfigExportService.printOrSavePdf(
                    context, state.filteredConfigs,
                    isArabic: isAr),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(l.stepConfigPrintPdfBtn,
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    StepConfigExportService.copyDossierToClipboard(
                        context, state.filteredConfigs,
                        isArabic: isAr),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: Text(l.stepConfigCopyDossierBtn,
                    style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searchAndFilters,
                const SizedBox(height: 10),
                exportToolbar,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchAndFilters),
              const SizedBox(width: 16),
              exportToolbar,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhaseFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          )),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.flatCobalt,
      backgroundColor: const Color(0xFFF1F5F9),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyView() {
    final l = context.l10n;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_off_rounded,
              size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            l.stepConfigEmptySearch,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<StepConfigModel> configs) {
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 76,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                      label: Text(l.stepConfigColActions,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColPhaseCode,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColStepName,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColSkipPolicy,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColApproverRoles,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColPendingRef,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColReasonCategories,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text(l.stepConfigColLastModified,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: configs
                    .map((cfg) => _buildDataRow(cfg, l, isAr))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildDataRow(
      StepConfigModel cfg, AppLocalizations l, bool isAr) {
    final rowSummary =
        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
    final localizedStepName = isAr ? cfg.stepNameAr : cfg.stepNameEn;
    final localizedPolicy = cfg.isBlocked
        ? l.stepConfigPolicyBlocked
        : (cfg.isDualApproval
            ? l.stepConfigPolicyDualApproval
            : l.stepConfigPolicySingleApproval);
    final localizedPendingRef = cfg.supportsPendingReference
        ? l.stepConfigPendingRefAllowed
        : l.stepConfigPendingRefBlocked;
    final reasonCountStr =
        l.stepConfigReasonCategoriesCount(cfg.reasonCategories.length);

    return DataRow(
      cells: [
        // 8. Actions (Quick Row Copy + Edit + Audit)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: Color(0xFF2C3E50), size: 18),
                tooltip: l.stepConfigCopyRowTooltip,
                onPressed: () {
                  CopyHelper.copy(context, rowSummary,
                      customMessage: l.stepConfigCopyRowSuccess);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded,
                    color: AppTheme.flatCobalt, size: 22),
                tooltip: l.stepConfigEditTooltip,
                onPressed: () => _showEditDialog(context, cfg),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded,
                    color: Color(0xFF2C3E50), size: 20),
                tooltip: l.stepConfigAuditTooltip,
                onPressed: () => _showAuditDialog(context, cfg),
              ),
            ],
          ),
        ),
        // 1. Code & Phase
        DataCell(
          CopyableTableCell(
            value: 'P${cfg.phaseId}-${cfg.stepCode}',
            rowSummary: rowSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'P${cfg.phaseId}',
                    style: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    CopyHelper.copy(
                      context,
                      cfg.stepCode,
                      customMessage: l.stepConfigCopyBadgeSuccess(
                          l.stepConfigColPhaseCode, cfg.stepCode),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cfg.stepCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded,
                            size: 13, color: AppTheme.flatCobalt),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Step Name (Single language according to active locale)
        DataCell(
          CopyableTableCell(
            value: localizedStepName,
            rowSummary: rowSummary,
            child: Text(
              localizedStepName,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // 3. Policy Badge
        DataCell(
          CopyableTableCell(
            value: localizedPolicy,
            rowSummary: rowSummary,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cfg.policyColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cfg.policyColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cfg.policyIcon, size: 14, color: cfg.policyColor),
                  const SizedBox(width: 6),
                  Text(
                    localizedPolicy,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cfg.policyColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Approver Roles
        DataCell(
          CopyableTableCell(
            value: cfg.approverRoles.join(', '),
            rowSummary: rowSummary,
            child: Wrap(
              spacing: 4,
              children: cfg.approverRoles.map((role) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                        fontSize: 11.0, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // 5. Pending Reference Supported
        DataCell(
          CopyableTableCell(
            value: localizedPendingRef,
            rowSummary: rowSummary,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cfg.supportsPendingReference
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  size: 16,
                  color: cfg.supportsPendingReference
                      ? const Color(0xFF27AE60)
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  localizedPendingRef,
                  style: TextStyle(
                    fontSize: 11,
                    color: cfg.supportsPendingReference
                        ? const Color(0xFF27AE60)
                        : Colors.grey,
                    fontWeight: cfg.supportsPendingReference
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 6. Reason categories count
        DataCell(
          CopyableTableCell(
            value: reasonCountStr,
            rowSummary: rowSummary,
            child: Tooltip(
              message: cfg.reasonCategories.join('\n'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt_rounded,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      reasonCountStr,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 7. Last modified
        DataCell(
          CopyableTableCell(
            value: '${cfg.lastModifiedBy ?? "-"} ${cfg.lastModifiedAt ?? ""}'
                .trim(),
            rowSummary: rowSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cfg.lastModifiedBy ?? '-',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500)),
                if (cfg.lastModifiedAt != null)
                  Text(cfg.lastModifiedAt!,
                      style: const TextStyle(
                          fontSize: 11.0, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ),


      ],
    );
  }

  void _showEditDialog(BuildContext context, StepConfigModel config) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _StepConfigEditDialog(config: config),
    );
  }

  void _showAuditDialog(BuildContext context, StepConfigModel config) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _StepConfigAuditHistoryDialog(config: config),
    );
  }
}

// ─── Edit Dialog with Mandatory Justification ────────────────────────────────

class _StepConfigEditDialog extends ConsumerStatefulWidget {
  final StepConfigModel config;

  const _StepConfigEditDialog({required this.config});

  @override
  ConsumerState<_StepConfigEditDialog> createState() =>
      _StepConfigEditDialogState();
}

class _StepConfigEditDialogState extends ConsumerState<_StepConfigEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _skipPolicy;
  late bool _supportsPendingReference;
  late List<String> _approverRoles;
  late List<String> _reasonCategories;
  final TextEditingController _justificationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _skipPolicy = widget.config.skipPolicy;
    _supportsPendingReference = widget.config.supportsPendingReference;
    _approverRoles = List.from(widget.config.approverRoles);
    _reasonCategories = List.from(widget.config.reasonCategories);
  }

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stepConfigProvider);
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;
    final stepName =
        isAr ? widget.config.stepNameAr : widget.config.stepNameEn;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.flatCobalt.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_suggest_rounded,
                  color: AppTheme.flatCobalt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.stepConfigEditDialogTitle(widget.config.stepCode),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    stepName,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip Policy selector
                  Text(l.stepConfigSkipPolicyLabel,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _skipPolicy,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'blocked',
                        child: Text(l.stepConfigPolicyItemBlocked),
                      ),
                      DropdownMenuItem(
                        value: 'single_approval',
                        child: Text(l.stepConfigPolicyItemSingleApproval),
                      ),
                      DropdownMenuItem(
                        value: 'dual_approval',
                        child: Text(l.stepConfigPolicyItemDualApproval),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _skipPolicy = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Supports Pending Reference Toggle
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Material(type: MaterialType.transparency, child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.stepConfigPendingRefToggleTitle,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        l.stepConfigPendingRefToggleSubtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      value: _supportsPendingReference,
                      activeColor: AppTheme.flatCobalt,
                      onChanged: (val) =>
                          setState(() => _supportsPendingReference = val),
                    )),
                  ),
                  const SizedBox(height: 16),

                  // Approver Roles
                  Text(l.stepConfigApproverRolesTitle,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    l.stepConfigApproverRolesSubtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final role in ['Manager', 'ADMIN', 'ComplianceHead'])
                        FilterChip(
                          label: Text(role),
                          selected: _approverRoles.contains(role),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _approverRoles.add(role);
                              } else {
                                if (_approverRoles.length > 1) {
                                  _approverRoles.remove(role);
                                }
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mandatory Justification Field
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_document,
                                size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.stepConfigJustificationTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _justificationController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: l.stepConfigJustificationHint,
                            hintStyle: const TextStyle(
                                fontSize: 11, color: Color(0xFFB45309)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length < 5) {
                              return l.stepConfigJustificationValidator;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.stepConfigCancelBtn),
          ),
          ElevatedButton.icon(
            onPressed: state.isSaving ? null : _handleSave,
            icon: state.isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(l.stepConfigSaveBtn),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.flatCobalt,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;

    final success =
        await ref.read(stepConfigProvider.notifier).updateStepConfig(
              stepCode: widget.config.stepCode,
              skipPolicy: _skipPolicy,
              reasonCategories: _reasonCategories,
              approverRoles: _approverRoles,
              supportsPendingReference: _supportsPendingReference,
              justification: _justificationController.text.trim(),
            );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.stepConfigSaveSuccess(widget.config.stepCode)),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    } else if (!success && mounted) {
      final error = ref.read(stepConfigProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }
}

// ─── Audit History Dialog ───────────────────────────────────────────────────

class _StepConfigAuditHistoryDialog extends ConsumerWidget {
  final StepConfigModel config;

  const _StepConfigAuditHistoryDialog({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF2C3E50)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.stepConfigAuditDialogTitle(config.stepCode),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 400,
          child: FutureBuilder<List<StepConfigAuditLogModel>>(
            future: ref
                .read(stepConfigProvider.notifier)
                .fetchAuditLogs(config.stepCode),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Center(
                  child: Text(
                    l.stepConfigAuditEmpty,
                    style: const TextStyle(
                        color: Color(0xFF7F8C8D), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (ctx, idx) {
                  final item = logs[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.stepConfigAuditBy(item.changedBy),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              item.changedAt,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(l.stepConfigAuditPolicyChange,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(width: 4),
                            Text(
                              '${item.oldPolicy ?? "blocked"} → ${item.newPolicy ?? "blocked"}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.flatCobalt,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${l.stepConfigAuditJustification} ${item.justification}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF334155)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    size: 14, color: AppTheme.flatCobalt),
                                tooltip: l.stepConfigCopyRowTooltip,
                                onPressed: () {
                                  CopyHelper.copy(
                                    context,
                                    item.justification,
                                    customMessage: l.stepConfigCopyRowSuccess,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.stepConfigAuditCloseBtn),
          ),
        ],
      ),
    );
  }
}
