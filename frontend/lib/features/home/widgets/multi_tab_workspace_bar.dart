import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_ar.dart';
import '../../../core/providers/ai_assistant_provider.dart';
import '../../../core/providers/workspace_tabs_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/unsaved_changes_dialog.dart';

String getLocalizedTabTitle(BuildContext context, int routeIndex, String fallbackTitle) {
  final l10n = AppLocalizations.of(context);

  final isArabic = l10n is AppLocalizationsAr;

  switch (routeIndex) {
    case 0: return isArabic ? 'لوحة التحكم' : 'Dashboard';
    case 1: return isArabic ? 'ملفات الشحنات' : 'Import Files';
    case 2: return isArabic ? 'أوامر الشراء' : 'Purchase Orders';
    case 3: return isArabic ? 'حاسبة CBM' : 'CBM Calculator';
    case 4:
    case 5: return l10n.freightStudies;
    case 6:
    case 7:
    case 55:
    case 56: return l10n.customsStudies;
    case 8:
    case 9:
    case 10: return l10n.financeApprovals;
    case 11:
    case 12:
    case 13:
    case 14:
    case 15: return l10n.acidOperations;
    case 16:
    case 17: return l10n.bankForm4;
    case 18:
    case 19:
    case 20:
    case 21:
    case 22:
    case 53: return l10n.draftDocsReview;
    case 23:
    case 24: return l10n.customsDeclaration46;
    case 25: return l10n.freightBooking;
    case 26:
    case 52: return l10n.cargoShippingTracking;
    case 27:
    case 60:
    case 61:
    case 62: return l10n.customsClearanceFollowup;
    case 28:
    case 63:
    case 64: return l10n.warehouseReceiving;
    case 29: return l10n.landedCostSettlement;
    case 30: return l10n.importFileFinalClosure;
    case 31: return l10n.projectsAndCostCenters;
    case 32: return l10n.importCompanies;
    case 33: return l10n.foreignSuppliers;
    case 34: return l10n.partnersAndBanks;
    case 35: return l10n.incotermsRules;
    case 36:
    case 45: return l10n.customsTariffSchedule;
    case 37: return l10n.portsAndLocations;
    case 38: return l10n.currenciesAndRates;
    case 39: return l10n.systemAuditLogs;
    case 40: return l10n.smartTasksAndAlerts;
    case 41: return l10n.dynamicReportBuilder;
    case 42: return l10n.quickUpdateEngine;
    case 43: return l10n.importRequirements;
    case 44: return l10n.demurrageDetention;
    case 46: return l10n.swiftReconciliation;
    case 47: return l10n.masterShipmentReport;
    case 48: return l10n.lifecycleBoard;
    case 49: return l10n.freightQuotations;
    case 50: return l10n.landedCostComparison;
    case 51: return l10n.centralDocsHub;
    case 54:
    case 57:
    case 58: return l10n.cargoXBlockchain;
    case 59: return l10n.productionSyncHub;
    case 65: return l10n.cargoInsurance;
    case 66: return l10n.userManagement;
    default: return fallbackTitle;
  }
}

class MultiTabWorkspaceBar extends ConsumerWidget {
  const MultiTabWorkspaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tabsState = ref.watch(workspaceTabsProvider);
    final tabsNotifier = ref.read(workspaceTabsProvider.notifier);
    final isDark = AppTheme.isDark(context);
    final density = ref.watch(displayDensityProvider);

    return Container(
      height: density.tabBarHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A22) : const Color(0xFFF1F4F8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabsState.tabs.length,
              itemBuilder: (context, index) {
                final tab = tabsState.tabs[index];
                final isActive = tab.id == tabsState.activeTabId;
                final localizedTitle = getLocalizedTabTitle(context, tab.routeIndex, tab.title);

                return GestureDetector(
                  onTap: () {
                    tabsNotifier.selectTab(tab.id);
                    ref.read(aiAssistantProvider.notifier).updateScreenContext(localizedTitle);
                  },
                  child: Container(
                    margin: EdgeInsetsDirectional.only(top: density.isUltraCompact ? 1 : 2, start: 2, end: 2),
                    padding: EdgeInsets.symmetric(horizontal: density.isUltraCompact ? 6 : 8),
                    constraints: BoxConstraints(
                      maxWidth: density.isUltraCompact ? 130 : 155,
                      minWidth: 60,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? AppTheme.darkCardBackground : Colors.white)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      border: isActive
                          ? Border.all(
                              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                              width: 1.0,
                            )
                          : null,
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: density.isUltraCompact ? 12 : 13.5,
                          color: isActive
                              ? AppTheme.cobalt
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            localizedTitle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: DisplayDensityMode.clampFontSize(density.isUltraCompact ? 11.0 : 11.8),
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              color: isActive
                                  ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                                  : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                            ),
                          ),
                        ),
                        if (tab.isDirty) ...[
                          const SizedBox(width: 5),
                          Tooltip(
                            message: l10n.unsavedChangesBadgeTooltip,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppTheme.crimson,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                        if (tab.isClosable) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              if (!tab.isDirty) {
                                tabsNotifier.closeTab(tab.id);
                                return;
                              }

                              final confirmed = await UnsavedChangesDialog.show(
                                context,
                                customMessage: '${l10n.unsavedChangesMessage}\n($localizedTitle)',
                              );
                              if (confirmed) {
                                tabsNotifier.setTabDirty(tab.id, false);
                                tabsNotifier.closeTab(tab.id);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(
                                Icons.close,
                                size: 13,
                                color: isActive
                                    ? (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)
                                    : (isDark ? AppTheme.darkTextMuted : Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          // Tab bar actions menu
          PopupMenuButton<String>(
            tooltip: l10n.tabOptionsTooltip,
            icon: Icon(
              Icons.more_horiz,
              size: 18,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
            ),
            onSelected: (value) {
              if (value == 'close_others') {
                tabsNotifier.closeOtherTabs(tabsState.activeTabId);
              } else if (value == 'close_all') {
                tabsNotifier.closeAllTabs();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'close_others',
                child: Row(
                  children: [
                    const Icon(Icons.tab_unselected_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(l10n.closeOtherTabs, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'close_all',
                child: Row(
                  children: [
                    const Icon(Icons.close_fullscreen_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(l10n.closeAllTabs, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

