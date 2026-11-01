import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import 'saved_scenarios/shipping_scenario_exporter.dart';
import 'saved_scenarios/shipping_scenarios_data_table.dart';
import 'saved_scenarios/shipping_scenarios_filter_bar.dart';
import 'saved_scenarios/shipping_scenarios_mobile_cards.dart';
import 'saved_scenarios/shipping_scenarios_stats_header.dart';
import 'saved_scenarios/shipping_session_details_dialog.dart';
import 'search_and_clone_study_dialog.dart';

class SavedScenariosRegistryTab extends ConsumerStatefulWidget {
  final void Function(ShippingEvaluationModel session) onEditSession;
  final VoidCallback onSwitchToEvaluator;

  const SavedScenariosRegistryTab({
    super.key,
    required this.onEditSession,
    required this.onSwitchToEvaluator,
  });

  @override
  ConsumerState<SavedScenariosRegistryTab> createState() => _SavedScenariosRegistryTabState();
}

class _SavedScenariosRegistryTabState extends ConsumerState<SavedScenariosRegistryTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shippingScenariosProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final l = context.l10n;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Summary Stats & Toolbar
          ShippingScenariosStatsHeader(
            sessions: state.sessions,
            onRefresh: () => ref.read(shippingScenariosProvider.notifier).fetchSessions(),
          ),

          // 2. Search & Filter Bar
          ShippingScenariosFilterBar(
            searchController: _searchController,
            showInactive: state.showInactive,
            totalCount: state.sessions.length,
            onSearchChanged: (v) {
              ref.read(shippingScenariosProvider.notifier).setSearchQuery(v);
            },
            onToggleShowInactive: (val) {
              ref.read(shippingScenariosProvider.notifier).toggleShowInactive(val);
            },
            onOpenSearchAndClone: () => _openSearchAndCloneStudyDialog(context, state.sessions),
          ),

          // 3. Data Content (Loading / Empty / Table / Mobile Cards)
          Expanded(
            child: state.isLoading
                ? const AppLoadingState()
                : state.sessions.isEmpty
                    ? AppEmptyState(
                        icon: Icons.folder_open_rounded,
                        message: _searchController.text.isNotEmpty
                            ? l.noResultsFound
                            : l.noDataFound,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 768) {
                            return ShippingScenariosMobileCards(
                              sessions: state.sessions,
                              importFiles: importFiles,
                              onView: (s) => ShippingSessionDetailsDialog.show(context, s, importFiles),
                              onEdit: widget.onEditSession,
                              onClone: (s) => _openCloneStudyReviewDialog(context, s),
                              onPrint: (s) => ShippingScenarioExporter.exportScenarioCsv(context, s, importFiles),
                              onDeleteOrRestore: (s) => _handleDeleteOrRestore(context, s, l),
                            );
                          }
                          return ShippingScenariosDataTable(
                            sessions: state.sessions,
                            importFiles: importFiles,
                            onView: (s) => ShippingSessionDetailsDialog.show(context, s, importFiles),
                            onEdit: widget.onEditSession,
                            onClone: (s) => _openCloneStudyReviewDialog(context, s),
                            onPrint: (s) => ShippingScenarioExporter.exportScenarioCsv(context, s, importFiles),
                            onDeleteOrRestore: (s) => _handleDeleteOrRestore(context, s, l),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteOrRestore(BuildContext context, ShippingEvaluationModel sess, AppLocalizations l) async {
    if (sess.isActive) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: l.confirmDelete,
        message: '${l.confirmDeleteStudyMessage} (${sess.sessionCode})',
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        confirmVariant: AppButtonVariant.danger,
        icon: Icons.warning_rounded,
      );
      if (confirm == true) {
        await ref.read(shippingScenariosProvider.notifier).deleteSession(sess.sessionId!);
      }
    } else {
      await ref.read(shippingScenariosProvider.notifier).restoreSession(sess.sessionId!);
    }
  }

  void _openCloneStudyReviewDialog(BuildContext context, ShippingEvaluationModel source) {
    final l = context.l10n;
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final initialName = '${source.title ?? source.sessionCode}${TableRowCloneHelper.copySuffix}';

    final copiedMap = <String, String>{
      l.shippingCarrierOptions: '${source.items.length}',
      l.crdLabel: source.cargoReadyDate,
    };
    if (source.recommendedScenarioProvider != null) {
      copiedMap[l.recommendedLineMetric] = source.recommendedScenarioProvider!;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: CloneEntityReviewDialog(
              entityType: l.cloneStudyDialogTitle,
              sourceCode: source.sessionCode,
              suggestedNewCode: '${source.sessionCode}-CLONE',
              sourceTitle: initialName,
              copiedFieldsSummary: copiedMap,
              mandatorilyResetFields: [
                l.cloneFieldStudyCodeGenerated,
                l.cloneFieldImportFileReset,
                l.cloneFieldPoReset,
                l.cloneFieldSelectionReset,
              ],
              onConfirm: ({
                required String newCode,
                required String newTitle,
                required bool copyLineItems,
                required bool copyAttachments,
                String? notes,
              }) async {
                final sId = source.sessionId;
                if (sId == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final cloned = await ref.read(shippingScenariosProvider.notifier).cloneSession(
                      sId,
                      newTitle: newTitle,
                      remarks: notes,
                      unlinkImportFile: true,
                      unlinkPo: true,
                      copyCarrierOptions: copyLineItems,
                    );
                if (!context.mounted) return;
                if (cloned != null) {
                  widget.onEditSession(cloned);
                  widget.onSwitchToEvaluator();
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    AppTheme.snackBar(
                      context,
                      l.cloneStudySuccess(cloned.sessionCode),
                      severity: AppSeverity.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    AppTheme.snackBar(
                      context,
                      ApiErrorText.of(l, ref.read(shippingScenariosProvider).error, fallback: l.operationFailed),
                      severity: AppSeverity.danger,
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchAndCloneStudyDialog(BuildContext context, List<ShippingEvaluationModel> sessions) {
    final textDir = Directionality.maybeOf(context) ?? TextDirection.rtl;
    final isArabic = textDir == TextDirection.rtl || Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isArabic ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: textDir,
          child: SelectionArea(
            child: SearchAndCloneStudyDialog(
              sessions: sessions,
              onSelectStudy: (session) {
                Navigator.of(dialogCtx).pop();
                _openCloneStudyReviewDialog(context, session);
              },
            ),
          ),
        ),
      ),
    );
  }
}
