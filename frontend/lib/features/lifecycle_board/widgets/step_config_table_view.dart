import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/step_config_model.dart';
import '../services/step_config_export_service.dart';

/// Enterprise DataTable rendering the collection of step governance configurations.
class StepConfigTableView extends StatelessWidget {
  final List<StepConfigModel> configs;
  final bool canManage;
  final void Function(StepConfigModel config) onShowEdit;
  final void Function(StepConfigModel config) onShowAudit;

  const StepConfigTableView({
    super.key,
    required this.configs,
    required this.canManage,
    required this.onShowEdit,
    required this.onShowAudit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;

    return SelectionArea(
      child: Column(
        children: [
          Expanded(
            child: EnterpriseDataTable<StepConfigModel>(
              storageKey: 'step_config_management_table',
              data: configs,
              rowHeight: 68,
              columns: [
                EnterpriseColumn<StepConfigModel>(
                  id: 'actions',
                  title: l.stepConfigColActions,
                  width: 140,
                  isSortable: false,
                  isSearchable: false,
                  cellBuilder: (context, cfg, index) => RowActionsPill(
                    viewTooltip: l.stepConfigAuditTooltip,
                    onView: () => onShowAudit(cfg),
                    editTooltip: canManage ? l.stepConfigEditTooltip : null,
                    onEdit: canManage ? () => onShowEdit(cfg) : null,
                    cloneTooltip: l.stepConfigCopyRowTooltip,
                    onClone: () {
                      final rowSummary =
                          StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                      CopyHelper.copy(
                        context,
                        rowSummary,
                        customMessage: l.stepConfigCopyRowSuccess,
                      );
                    },
                  ),
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'phaseCode',
                  title: l.stepConfigColPhaseCode,
                  width: 150,
                  exportValue: (cfg) => 'P${cfg.phaseId}-${cfg.stepCode}',
                  searchValue: (cfg) => 'P${cfg.phaseId} ${cfg.stepCode}',
                  cellBuilder: (context, cfg, index) {
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: 'P${cfg.phaseId}-${cfg.stepCode}',
                      rowSummary: rowSummary,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P${cfg.phaseId}',
                              style: const TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              CopyHelper.copy(
                                context,
                                cfg.stepCode,
                                customMessage: l.stepConfigCopyBadgeSuccess(
                                  l.stepConfigColPhaseCode,
                                  cfg.stepCode,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cfg.stepCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.flatCobalt,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: AppTheme.flatCobalt,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'stepName',
                  title: l.stepConfigColStepName,
                  flex: 2,
                  exportValue: (cfg) => isAr ? cfg.stepNameAr : cfg.stepNameEn,
                  searchValue: (cfg) => '${cfg.stepNameAr} ${cfg.stepNameEn}',
                  cellBuilder: (context, cfg, index) {
                    final localizedStepName = isAr ? cfg.stepNameAr : cfg.stepNameEn;
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: localizedStepName,
                      rowSummary: rowSummary,
                      child: Text(
                        localizedStepName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'skipPolicy',
                  title: l.stepConfigColSkipPolicy,
                  width: 140,
                  exportValue: (cfg) => cfg.isBlocked
                      ? l.stepConfigPolicyBlocked
                      : (cfg.isDualApproval
                          ? l.stepConfigPolicyDualApproval
                          : l.stepConfigPolicySingleApproval),
                  cellBuilder: (context, cfg, index) {
                    final localizedPolicy = cfg.isBlocked
                        ? l.stepConfigPolicyBlocked
                        : (cfg.isDualApproval
                            ? l.stepConfigPolicyDualApproval
                            : l.stepConfigPolicySingleApproval);
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: localizedPolicy,
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cfg.policyColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cfg.policyColor.withValues(alpha: 0.3)),
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
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'approverRoles',
                  title: l.stepConfigColApproverRoles,
                  width: 180,
                  exportValue: (cfg) => cfg.approverRoles.join(', '),
                  cellBuilder: (context, cfg, index) {
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: cfg.approverRoles.join(', '),
                      rowSummary: rowSummary,
                      child: Wrap(
                        spacing: 4,
                        children: cfg.approverRoles.map((role) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                fontSize: 11.0,
                                color: Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'pendingRef',
                  title: l.stepConfigColPendingRef,
                  width: 140,
                  exportValue: (cfg) => cfg.supportsPendingReference
                      ? l.stepConfigPendingRefAllowed
                      : l.stepConfigPendingRefBlocked,
                  cellBuilder: (context, cfg, index) {
                    final localizedPendingRef = cfg.supportsPendingReference
                        ? l.stepConfigPendingRefAllowed
                        : l.stepConfigPendingRefBlocked;
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
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
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'reasonCategories',
                  title: l.stepConfigColReasonCategories,
                  width: 160,
                  exportValue: (cfg) =>
                      l.stepConfigReasonCategoriesCount(cfg.reasonCategories.length),
                  cellBuilder: (context, cfg, index) {
                    final reasonCountStr =
                        l.stepConfigReasonCategoriesCount(cfg.reasonCategories.length);
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: reasonCountStr,
                      rowSummary: rowSummary,
                      child: Tooltip(
                        message: cfg.reasonCategories
                            .map((c) => DomainEnums.label(
                                context.l10n, DomainEnumType.skipReasonCategory, c))
                            .join('\n'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.list_alt_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                reasonCountStr,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                EnterpriseColumn<StepConfigModel>(
                  id: 'lastModified',
                  title: l.stepConfigColLastModified,
                  width: 160,
                  exportValue: (cfg) =>
                      '${cfg.lastModifiedBy ?? "-"} ${cfg.lastModifiedAt ?? ""}'.trim(),
                  cellBuilder: (context, cfg, index) {
                    final rowSummary =
                        StepConfigExportService.toRowSummary(cfg, l, isArabic: isAr);
                    return CopyableTableCell(
                      value: '${cfg.lastModifiedBy ?? "-"} ${cfg.lastModifiedAt ?? ""}'.trim(),
                      rowSummary: rowSummary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            cfg.lastModifiedBy ?? '-',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          if (cfg.lastModifiedAt != null)
                            Text(
                              cfg.lastModifiedAt!,
                              style: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
