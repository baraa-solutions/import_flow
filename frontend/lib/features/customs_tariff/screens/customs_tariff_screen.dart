import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/customs_tariff_provider.dart';
import '../widgets/duty_calculator_dialog.dart';
import '../widgets/nafeza_details_dialog.dart';
import '../widgets/tariff_form_dialog.dart';
import '../widgets/screen/customs_tariff_export_helper.dart';
import '../widgets/screen/customs_tariff_table.dart';
import '../widgets/screen/customs_tariff_toolbar.dart';
import 'hs_code_search_screen.dart';

class CustomsTariffScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const CustomsTariffScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<CustomsTariffScreen> createState() => _CustomsTariffScreenState();
}

class _CustomsTariffScreenState extends ConsumerState<CustomsTariffScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    if (!ref.read(customsTariffProvider).isLoading) {
      Future.microtask(() {
        ref.read(customsTariffProvider.notifier).fetchTariffs();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CustomsTariffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() => _currentTab = widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tariffsAsync = ref.watch(customsTariffProvider);
    final showInactive = ref.watch(showInactiveCustomsTariffsProvider);
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.receipt_long_outlined,
        title: l10n.customsTariffScreenTitle,
        subtitle: l10n.customsTariffScreenSubtitle,
        actions: [
          SegmentedButton<int>(
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.cobalt;
                }
                return Colors.white12;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white70;
              }),
            ),
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: Text(l10n.customsTariffScreenTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.saved_search, size: 16),
                label: Text(l10n.hsExplorerBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            selected: {_currentTab},
            onSelectionChanged: (set) => setState(() => _currentTab = set.first),
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: _currentTab == 1
            ? HsCodeSearchScreen(
                key: const ValueKey('hs_explorer_tab_view'),
                initialQuery: _searchController.text,
                isEmbedded: true,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomsTariffToolbar(
                      density: density,
                      searchController: _searchController,
                      showInactive: showInactive,
                      hasTariffs: (tariffsAsync.valueOrNull ?? []).isNotEmpty,
                      onAddManual: () => showTariffDialog(context, ref, initialModeIndex: 1),
                      onSmartNafeza: () => showTariffDialog(context, ref, initialModeIndex: 0),
                      onDutyCalculator: () => showDutyCalculatorDialog(context, ref),
                      onMoreActionSelected: (val) {
                        if (val == 'import_excel') {
                          CustomsTariffExportHelper.handleExcelImport(context, ref);
                        } else {
                          MasterDataActionHelper.handleStandardAction(
                            context: context,
                            ref: ref,
                            actionValue: val,
                            moduleEndpoint: 'customs-tariff',
                            entityNameAr: 'التعريفة الجمركية',
                            entityNameEn: 'Customs Tariff Schedule',
                            entityFilePrefix: 'Customs_Tariff_Schedule',
                            onCopyTsv: () => CustomsTariffExportHelper.copyTariffsTsv(
                              context,
                              tariffsAsync.valueOrNull ?? [],
                            ),
                          );
                        }
                      },
                      onSearchChanged: (val) {
                        ref.read(customsTariffSearchQueryProvider.notifier).state = val.trim();
                      },
                      onToggleShowInactive: (val) {
                        ref.read(showInactiveCustomsTariffsProvider.notifier).state = val;
                      },
                      onRefresh: () => ref.read(customsTariffProvider.notifier).fetchTariffs(),
                      onCopyTsv: () => CustomsTariffExportHelper.copyTariffsTsv(
                        context,
                        tariffsAsync.valueOrNull ?? [],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: tariffsAsync.when(
                        loading: () => const AppLoadingState(),
                        error: (e, _) => AppErrorState(
                          error: e,
                          onRetry: () => ref.read(customsTariffProvider.notifier).fetchTariffs(),
                        ),
                        data: (tariffs) {
                          final query = _searchController.text.trim().toLowerCase().replaceAll('.', '');
                          final filteredTariffs = query.isEmpty
                              ? tariffs
                              : tariffs.where((t) {
                                  final hsClean = t.hsCode.toLowerCase().replaceAll('.', '');
                                  final desc = t.hsDescription.toLowerCase();
                                  final cat = t.categorySearchText;
                                  final auth = (t.regulatoryAuthority ?? '').toLowerCase();
                                  final note = (t.priorApprovalNote ?? '').toLowerCase();
                                  return hsClean.contains(query) ||
                                      desc.contains(query) ||
                                      cat.contains(query) ||
                                      auth.contains(query) ||
                                      note.contains(query);
                                }).toList();

                          if (filteredTariffs.isEmpty) {
                            return AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              message: _searchController.text.isNotEmpty
                                  ? l10n.noTariffsMatchingQuery(_searchController.text)
                                  : l10n.noTariffsFound,
                            );
                          }
                          return CustomsTariffTable(
                            tariffs: filteredTariffs,
                            onViewDetails: (t) => showNafezaDetailsDialog(context, ref, t),
                            onEdit: (t) => showTariffDialog(context, ref, tariff: t),
                            onPrint: (t) async {
                              final agreements = await ref
                                  .read(customsTariffProvider.notifier)
                                  .fetchAgreements(t.hsCode);
                              if (context.mounted) {
                                await MasterDataExportService.printOrSaveTariffPdf(t, agreements);
                              }
                            },
                            onToggleActive: (t) async {
                              final isActive = t.isActive;
                              final confirm = await AppConfirmDialog.showToggleActive(
                                context,
                                isCurrentlyActive: isActive,
                                message: isActive
                                    ? l10n.confirmDeactivateTariff(t.hsCode)
                                    : l10n.confirmActivateTariff(t.hsCode),
                                confirmLabel: isActive ? l10n.deactivateBtn : l10n.activateBtn,
                                cancelLabel: l10n.cancel,
                              );
                              if (confirm == true) {
                                await ref
                                    .read(customsTariffProvider.notifier)
                                    .toggleActive(t.tariffId, t.isActive);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
