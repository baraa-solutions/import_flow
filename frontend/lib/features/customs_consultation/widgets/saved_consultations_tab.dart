import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import 'consultation_metric_badge.dart';
import 'consultation_status_badges.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import 'search_and_clone_consultation_dialog.dart';
import 'package:printing/printing.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../services/customs_consultation_pdf_service.dart';
import '../services/customs_export_service.dart';
import '../../../core/widgets/table_row_clone_helper.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/localization/api_error_text.dart';

class SavedConsultationsTab extends ConsumerStatefulWidget {
  final Function(CustomsConsultationModel) onEdit;
  final Function(BuildContext, CustomsConsultationModel) onViewDetails;
  final bool isTaxReviewOnly;

  const SavedConsultationsTab({
    super.key,
    required this.onEdit,
    required this.onViewDetails,
    this.isTaxReviewOnly = false,
  });

  @override
  ConsumerState<SavedConsultationsTab> createState() => _SavedConsultationsTabState();
}

class _SavedConsultationsTabState extends ConsumerState<SavedConsultationsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _showInactive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCloneConsultationReviewDialog(BuildContext context, CustomsConsultationModel source) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialTitle = '${source.title}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.customsBrokerLabel: source.brokerName.isNotEmpty ? source.brokerName : '—',
      l.customsInspectionReadiness: '${source.checklistItems.length} ${l.itemsAndDocsCount}',
    };
    if (source.estimatedDutiesEgp > 0) {
      copiedMap[l.totalTaxesAndDutiesCol] = '${source.estimatedDutiesEgp.toStringAsFixed(2)} ${context.l10n.financialSettlementCurrencyEgp}';
    }
    if (source.brokerQuoteItems.isNotEmpty) {
      copiedMap[l.clearanceBrokerFeeItem] = '${source.brokerQuoteItems.length}';
    }

    final mandatorilyReset = <String>[
      l.cloneFieldConsultationCodeGenerated,
      l.cloneFieldImportFileReset,
      l.cloneFieldChecklistReset,
      l.cloneFieldStatusDraftBadge,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: CloneEntityReviewDialog(
            entityType: l.cloneConsultationDialogTitle,
            sourceCode: source.consultationCode,
            sourceTitle: initialTitle,
            suggestedNewCode: '${source.consultationCode}-CLONE',
            copiedFieldsSummary: copiedMap,
            mandatorilyResetFields: mandatorilyReset,
            allowCopyLineItems: true,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final messenger = ScaffoldMessenger.of(context);
              final payload = {
                'new_consultation_code': newCode,
                'new_title': newTitle,
                'copy_checklist_items': copyLineItems,
                'copy_broker_quote_items': copyLineItems,
                'notes': notes,
              };
              try {
                final cloned = await ref.read(customsConsultationsProvider.notifier).cloneConsultation(
                  source.consultationId,
                  payload,
                );
                if (cloned != null) {
                  widget.onEdit(cloned);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✨ ${l.cloneConsultationSuccess(cloned.consultationCode)}'),
                      backgroundColor: AppTheme.wcagEmerald,
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('❌ ${l.cloneConsultationError(e.toString())}'),
                    backgroundColor: AppTheme.crimson,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _openSearchAndCloneConsultationDialog(BuildContext context, List<CustomsConsultationModel> consultations) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SearchAndCloneConsultationDialog(
            consultations: consultations,
            onSelectConsultation: (consultation) {
              Navigator.of(dialogCtx).pop();
              _openCloneConsultationReviewDialog(context, consultation);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteOrRestore(CustomsConsultationModel session) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (session.isActive == false) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.restore_from_trash_rounded, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Text(l.restoreConsultationTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.restoreConsultationMsg(session.consultationCode, session.title),
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            AppButton(
              label: l.restoreAndActivateBtn,
              icon: Icons.restore_rounded,
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await ref.read(customsConsultationsProvider.notifier).restoreConsultation(session.consultationId);
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('♻️ ${l.restoreConsultationSuccess(session.consultationCode)}'),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('❌ ${ApiErrorText.of(l, e)}'),
                backgroundColor: AppTheme.crimson,
              ),
            );
          }
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: AppTheme.orange, size: 22),
              const SizedBox(width: 8),
              Text(l.deleteConsultationTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.deleteConsultationMsg(session.consultationCode, session.title),
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            AppButton(
              label: l.deleteAndArchiveBtn,
              icon: Icons.delete_rounded,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await ref.read(customsConsultationsProvider.notifier).softDeleteConsultation(session.consultationId);
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('🗑️ ${l.deleteConsultationSuccess(session.consultationCode)}'),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('❌ ${ApiErrorText.of(l, e)}'),
                backgroundColor: AppTheme.crimson,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;
    final consultationsState = ref.watch(customsConsultationsProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return consultationsState.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.cobalt),
            const SizedBox(height: 16),
            Text(l.loading, style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
      error: (err, stack) => Center(child: Text('${l.error}: $err')),
      data: (allSessions) {
        final sessions = widget.isTaxReviewOnly
            ? allSessions.where((s) => s.estimatedDutiesEgp > 0).toList()
            : allSessions;

        final filtered = sessions.where((s) {
          final rawFileCode = s.importFileCode ?? (s.importFileId != null ? 'IMP-${s.importFileId}' : '');
          final shipmentTitle = rawFileCode.isNotEmpty
              ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
              : '';
          final matchQuery = _searchQuery.isEmpty ||
              s.consultationCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.brokerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              rawFileCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              shipmentTitle.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchStatus = _statusFilter == 'All' || s.overallStatus == _statusFilter;
          return matchQuery && matchStatus;
        }).toList();

        // Aggregate metrics for header strip
        final totalCount = sessions.length;
        final readyCount = sessions.where((s) => s.overallStatus == 'Clearance Ready').length;
        final blockedCount = sessions.where((s) => s.overallStatus == 'Blocked' || s.hasBlockingIssues).length;
        final avgReadiness = sessions.isEmpty
            ? 0.0
            : sessions.fold(0.0, (s, c) => s + c.readinessPercentage) / sessions.length;

        // Metric Badges List
        final metricBadges = [
          ConsultationMetricBadge(
            title: l.totalStudiesMetric,
            value: '$totalCount',
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
          ConsultationMetricBadge(
            title: l.clearanceReadyStatus,
            value: '$readyCount',
            color: AppTheme.emerald,
          ),
          ConsultationMetricBadge(
            title: l.openBlockingIssues,
            value: '$blockedCount',
            color: blockedCount > 0 ? AppTheme.crimson : AppTheme.textMuted,
          ),
          ConsultationMetricBadge(
            title: l.avgReadinessMetric,
            value: '${avgReadiness.toStringAsFixed(0)}%',
            color: AppTheme.cobalt,
          ),
        ];

        // Search Input Widget
        final searchWidget = TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l.searchConsultationsHint,
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, val, _) {
                return val.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : const SizedBox.shrink();
              },
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        );

        // Status Dropdown Widget
        final statusWidget = SearchableDropdownField<String>(
          value: _statusFilter,
          labelText: l.statusFilterLabel,
          items: [
            SearchableDropdownItem(value: 'All', label: l.allStatuses),
            SearchableDropdownItem(value: 'Pending Review', label: l.statusPendingReview),
            SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
            SearchableDropdownItem(value: 'Action Required', label: l.statusActionRequired),
            SearchableDropdownItem(value: 'Clearance Ready', label: l.statusClearanceReady),
            SearchableDropdownItem(value: 'Blocked', label: l.statusBlocked),
          ],
          onChanged: (v) => setState(() => _statusFilter = v!),
        );

        // Clone Button
        final cloneButton = Tooltip(
          message: l.searchAndCloneConsultationTooltip,
          child: AppButton(
            key: const ValueKey('searchAndCloneConsultationBtnTab1'),
            label: l.searchAndCloneConsultationBtn,
            icon: Icons.control_point_duplicate_rounded,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => _openSearchAndCloneConsultationDialog(context, sessions),
          ),
        );

        // Filter Chip & Counter
        final filterChipWidget = FilterChip(
          avatar: Icon(_showInactive ? Icons.visibility_off : Icons.visibility, size: 16),
          label: Text(_showInactive ? l.hideArchivedChip : l.showArchivedChip),
          selected: _showInactive,
          selectedColor: isDark ? AppTheme.crimson.withValues(alpha: 0.5) : AppTheme.crimsonBorder,
          onSelected: (val) {
            setState(() => _showInactive = val);
            ref.read(customsConsultationsProvider.notifier).fetchConsultations(includeInactive: val);
          },
        );

        final countBadgeWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${filtered.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
          ),
        );

        // Export Action Buttons
        final exportButtons = [
          AppButton(
            label: l.customsTaxExportTsvBtn,
            icon: Icons.table_view_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => CustomsExportService.exportConsultationsLogTsv(
              context: context,
              sessions: filtered,
              shipments: importFiles,
            ),
          ),
          AppButton(
            label: l.customsTaxExportExcelBtn,
            icon: Icons.description_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => CustomsExportService.exportConsultationsLogExcel(
              context: context,
              sessions: filtered,
              shipments: importFiles,
            ),
          ),
          AppButton(
            label: l.customsTaxPrintPdfBtn,
            icon: Icons.picture_as_pdf_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => CustomsConsultationPdfService.printOrPreviewConsultationsLogPdf(context, filtered),
          ),
          AppButton(
            label: l.customsTaxCopyDossierBtn,
            icon: Icons.copy_all_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => CustomsExportService.copyConsultationsLogDossier(
              context: context,
              sessions: filtered,
              shipments: importFiles,
            ),
          ),
        ];

        return SelectionArea(
          child: Column(
            children: [
              // ── Metrics & Toolbar Strip ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.03),
                  border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
                ),
                child: LayoutBuilder(
                  builder: (context, tbConstraints) {
                    final isMobile = tbConstraints.maxWidth < 700;

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Metric badges in compact horizontal scroll
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: metricBadges.map((b) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: b)).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 2. Search & Filter Row
                          Row(
                            children: [
                              Expanded(flex: 3, child: searchWidget),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: statusWidget),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 3. Clone & Actions row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                cloneButton,
                                const SizedBox(width: 8),
                                filterChipWidget,
                                const SizedBox(width: 8),
                                countBadgeWidget,
                                const SizedBox(width: 8),
                                ...exportButtons.map((b) => Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: b)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    // Desktop / Tablet layout
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Left group: Metric Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: metricBadges,
                        ),

                        // Right group: Search & Filter Controls
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            cloneButton,
                            SizedBox(width: 220, child: searchWidget),
                            SizedBox(width: 160, child: statusWidget),
                            filterChipWidget,
                            countBadgeWidget,
                            ...exportButtons,
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Data Content Area (Responsive: Desktop Table vs. Mobile Cards) ────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: isDark ? AppTheme.textStrong : AppTheme.cloudWhite),
                            const SizedBox(height: 16),
                            Text(
                              l.noResultsFound,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 768) {
                            return _buildMobileConsultationsList(filtered, importFiles, isDark, isArabic);
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                            child: Card(
                              elevation: 2,
                              color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 48,
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 76,
                                  horizontalMargin: 16,
                                  columnSpacing: 20,
                                  dividerThickness: 0.5,
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                                  ),
                                  headingTextStyle: const TextStyle(
                                    color: AppTheme.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: SizedBox(
                                        width: 190,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                              l.actionsCol,
                                              style: const TextStyle(
                                                color: AppTheme.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataColumn(label: Text('📋 ${l.studyCodeCol}')),
                                    DataColumn(label: Text('📁 ${l.linkImportFile}')),
                                    DataColumn(label: Text('📝 ${l.titleField}')),
                                    DataColumn(label: Text('🧑‍💼 ${l.customsBrokerLabel}')),
                                    DataColumn(label: Text('💰 ${l.customsDutyCol}')),
                                    DataColumn(label: Text('📊 ${l.customsInspectionReadiness}')),
                                    DataColumn(label: Text('🔖 ${l.statusCol}')),
                                  ],
                                  rows: filtered.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final session = entry.value;
                                    final isEven = idx.isEven;
                                    final rowColor = isDark
                                        ? (isEven ? AppTheme.darkCardBackground : AppTheme.darkElevatedSurface)
                                        : (isEven ? AppTheme.white : AppTheme.charcoalSurface);
                                    final readinessPct = session.readinessPercentage;
                                    final hasBlocking = session.hasBlockingIssues || session.blockingIssuesCount > 0;
                                    final rawFileCode = session.importFileCode ?? (session.importFileId != null ? 'IMP-${session.importFileId}' : '—');
                                    final shipmentTitle = (rawFileCode != '—')
                                        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
                                        : '—';
                                    final fileDisplay = (shipmentTitle != '—' && shipmentTitle != rawFileCode)
                                        ? '$shipmentTitle ($rawFileCode)'
                                        : shipmentTitle;
                                    final rowSummary =
                                        '${session.consultationCode} | $fileDisplay | ${session.title} | ${session.brokerName} | ${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel | ${readinessPct.toStringAsFixed(0)}% | ${session.overallStatus}';

                                    return DataRow(
                                      color: WidgetStateProperty.all(rowColor),
                                      onSelectChanged: (_) => widget.onViewDetails(context, session),
                                      cells: [
                                        // ⚡ 1. Actions
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RowActionsPill(
                                                onView: () => widget.onViewDetails(context, session),
                                                onEdit: () => widget.onEdit(session),
                                                onClone: () => _openCloneConsultationReviewDialog(context, session),
                                                cloneTooltip: l.cloneConsultationTooltip,
                                                onPrint: () {
                                                  Printing.layoutPdf(
                                                    onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(session),
                                                    name: 'Customs_Consultation_${session.consultationCode}',
                                                  );
                                                },
                                                onDelete: () => _handleDeleteOrRestore(session),
                                                deleteTooltip: session.isActive == false ? l.restoreDeletedTooltip : l.deleteStudyTooltip,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                                                tooltip: l.copyTooltip,
                                                onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.customsTaxCopyRowSuccess),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 2. Consultation Code
                                        DataCell(
                                          CopyableTableCell(
                                            value: session.consultationCode,
                                            rowSummary: rowSummary,
                                            child: InkWell(
                                              onTap: () => widget.onViewDetails(context, session),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cobalt.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                                                ),
                                                child: Text(
                                                  session.consultationCode,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 3. Import File
                                        DataCell(
                                          CopyableTableCell(
                                            value: fileDisplay,
                                            rowSummary: rowSummary,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  shipmentTitle,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: isDark ? AppTheme.darkTextPrimary : null,
                                                  ),
                                                ),
                                                if (rawFileCode != '—' && rawFileCode != shipmentTitle) ...[
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.cobalt.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Text(
                                                      rawFileCode,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.cobalt,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),

                                        // 4. Title
                                        DataCell(
                                          CopyableTableCell(
                                            value: session.title,
                                            rowSummary: rowSummary,
                                            child: SizedBox(
                                              width: 180,
                                              child: Text(
                                                session.title,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? AppTheme.darkTextPrimary : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 5. Broker
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${session.brokerName}${session.brokerContactPerson != null ? " (${session.brokerContactPerson})" : ""}',
                                            rowSummary: rowSummary,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  session.brokerName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: isDark ? AppTheme.darkTextPrimary : null,
                                                  ),
                                                ),
                                                if (session.brokerContactPerson != null)
                                                  Text(
                                                    session.brokerContactPerson!,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // 6. Estimated Duties
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                                            rowSummary: rowSummary,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.crimson.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 7. Readiness Progress Bar
                                        DataCell(
                                          CopyableTableCell(
                                            value: '${readinessPct.toStringAsFixed(0)}%',
                                            rowSummary: rowSummary,
                                            child: SizedBox(
                                              width: 145,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${readinessPct.toStringAsFixed(0)}%',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                          color: readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                                                        ),
                                                      ),
                                                      if (hasBlocking)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.crimson.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            l.blockingIssuesBadge(session.blockingIssuesCount),
                                                            style: const TextStyle(color: AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: (readinessPct / 100).clamp(0.0, 1.0),
                                                      minHeight: 6,
                                                      backgroundColor: isDark ? AppTheme.charcoal : AppTheme.cloudWhite,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    l.approvedDocsCountBadge(session.approvedDocumentsCount, session.totalDocumentsCount),
                                                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 8. Status Badge
                                        DataCell(
                                          CopyableTableCell(
                                            value: session.overallStatus,
                                            rowSummary: rowSummary,
                                            child: ConsultationStatusBadge(status: session.overallStatus),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileConsultationsList(
    List<CustomsConsultationModel> sessions,
    List<ImportFileModel> importFiles,
    bool isDark,
    bool isArabic,
  ) {
    final l = context.l10n;
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 24),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final rawFileCode = session.importFileCode ?? (session.importFileId != null ? 'IMP-${session.importFileId}' : '—');
        final shipmentTitle = (rawFileCode != '—')
            ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
            : '—';
        final fileDisplay = (shipmentTitle != '—' && shipmentTitle != rawFileCode)
            ? '$shipmentTitle ($rawFileCode)'
            : shipmentTitle;
        final readinessPct = session.readinessPercentage;
        final hasBlocking = session.hasBlockingIssues || session.blockingIssuesCount > 0;
        final rowSummary =
            '${session.consultationCode} | $fileDisplay | ${session.title} | ${session.brokerName} | ${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel | ${readinessPct.toStringAsFixed(0)}% | ${session.overallStatus}';

        return Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onViewDetails(context, session),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Code & Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          session.consultationCode,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      ConsultationStatusBadge(status: session.overallStatus),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Title
                  Text(
                    session.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Row 3: Import File & Broker
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (rawFileCode != '—')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            const SizedBox(width: 4),
                            Text(
                              fileDisplay,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            ),
                          ],
                        ),
                      if (session.brokerName.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            const SizedBox(width: 4),
                            Text(
                              session.brokerName,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 4: Duties Badge & Readiness
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (session.estimatedDutiesEgp > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${session.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 11),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${readinessPct.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                            ),
                          ),
                          if (hasBlocking) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.crimson.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l.blockingIssuesBadge(session.blockingIssuesCount),
                                style: const TextStyle(color: AppTheme.crimson, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (readinessPct / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? AppTheme.charcoal : AppTheme.cloudWhite,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        readinessPct >= 80 ? AppTheme.emerald : (readinessPct >= 50 ? AppTheme.orange : AppTheme.crimson),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Row 5: Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RowActionsPill(
                        onView: () => widget.onViewDetails(context, session),
                        onEdit: () => widget.onEdit(session),
                        onClone: () => _openCloneConsultationReviewDialog(context, session),
                        cloneTooltip: l.cloneConsultationTooltip,
                        onPrint: () {
                          Printing.layoutPdf(
                            onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(session),
                            name: 'Customs_Consultation_${session.consultationCode}',
                          );
                        },
                        onDelete: () => _handleDeleteOrRestore(session),
                        deleteTooltip: session.isActive == false ? l.restoreDeletedTooltip : l.deleteStudyTooltip,
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: l.copyTooltip,
                        onPressed: () => CopyHelper.copy(context, rowSummary, customMessage: l.customsTaxCopyRowSuccess),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
