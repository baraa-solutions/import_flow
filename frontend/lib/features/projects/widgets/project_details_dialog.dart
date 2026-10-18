import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../audit_logs/providers/audit_logs_provider.dart';
import '../models/project_model.dart';

class ProjectDetailsDialog extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback? onEdit;

  const ProjectDetailsDialog({
    super.key,
    required this.project,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    ProjectModel project, {
    VoidCallback? onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProjectDetailsDialog(project: project, onEdit: onEdit),
    );
  }

  String _getStatusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'Open':
        return l10n.statusOpen;
      case 'Closed':
        return l10n.statusClosed;
      case 'On Hold':
        return l10n.statusOnHold;
      default:
        return status;
    }
  }

  String _getPriorityLabel(BuildContext context, String priority) {
    final l10n = context.l10n;
    switch (priority) {
      case 'High':
      case 'High / مرتفع':
        return l10n.priorityHigh;
      case 'Medium':
      case 'Medium / متوسط':
        return l10n.priorityMedium;
      case 'Low':
      case 'Low / منخفض':
        return l10n.priorityLow;
      case 'Urgent':
      case 'Urgent / حرج':
        return l10n.priorityUrgent;
      default:
        return priority;
    }
  }

  String _getImportTypeLabel(BuildContext context, String importType) {
    final l10n = context.l10n;
    if (importType.contains('Direct Commercial') || importType == 'Direct Commercial') {
      return l10n.importTypeDirectCommercial;
    }
    if (importType.contains('Free Zone') || importType == 'Free Zone') {
      return l10n.importTypeFreeZone;
    }
    if (importType.contains('Temporary Release') || importType.contains('السماح المؤقت')) {
      return l10n.importTypeTemporaryRelease;
    }
    if (importType.contains('Drawback') || importType == 'Drawback') {
      return l10n.importTypeDrawback;
    }
    if (importType.contains('Project Equipment') || importType.contains('معدات مشروعات')) {
      return l10n.importTypeProjectEquipment;
    }
    return importType;
  }

  String _getCategoryLabel(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category.trim()) {
      case 'FCL Container':
        return l10n.categoryFclContainer;
      case 'LCL Breakbulk':
        return l10n.categoryLclBreakbulk;
      case 'Air Freight':
        return l10n.categoryAirFreight;
      case 'Bulk Cargo':
        return l10n.categoryBulkCargo;
      case 'Multimodal':
        return l10n.categoryMultimodal;
      case 'Courier':
        return l10n.categoryCourier;
      default:
        return category;
    }
  }

  String _buildProjectSummary(BuildContext context) {
    final l10n = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final b = StringBuffer();
    b.writeln('📋 [${project.projectCode}] ${project.projectName}');
    b.writeln('${l10n.projectOwnerLabelField.replaceAll('*', '').trim()}: ${project.projectOwner}');
    if (project.companyName != null && project.companyName!.isNotEmpty) {
      b.writeln('${l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim()}: ${project.companyName}');
    }
    if (project.supplierName != null && project.supplierName!.isNotEmpty) {
      b.writeln('${l10n.primarySupplierLabel.replaceAll('*', '').trim()}: ${project.supplierName}');
    }
    if (project.incotermCode != null) {
      b.writeln('${l10n.defaultIncotermLabel.replaceAll('*', '').trim()}: ${project.incotermCode}');
    }
    b.writeln('${l10n.importTypeLabel.replaceAll('*', '').trim()}: ${_getImportTypeLabel(context, project.importType)}');
    b.writeln('${l10n.priorityLabel}: ${_getPriorityLabel(context, project.priority)}');
    if (project.totalBudgetUsd != null) {
      b.writeln('${l10n.budgetUsdCol}: ${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}');
    }
    if (project.totalCommittedUsd != null) {
      b.writeln('${isArabic ? "الالتزامات والارتباطات" : "Committed Budget"}: ${project.budgetCurrency} ${project.totalCommittedUsd!.toStringAsFixed(2)}');
    }
    if (project.remainingBudgetUsd != null) {
      b.writeln('${isArabic ? "المتبقي من الموازنة" : "Remaining Budget"}: ${project.budgetCurrency} ${project.remainingBudgetUsd!.toStringAsFixed(2)}');
    }
    b.writeln('${l10n.statusCol}: ${_getStatusLabel(context, project.status)} (${project.isActive ? l10n.statusActive : l10n.statusInactive})');
    if (project.targetEndDate != null && project.targetEndDate!.isNotEmpty) {
      b.writeln('${l10n.targetEndDateLabel}: ${project.targetEndDate}');
    }
    if (project.notes != null && project.notes!.isNotEmpty) {
      b.writeln('${l10n.projectNotesLabel}: ${project.notes}');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final isActive = project.isActive;
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(820.0, 1100.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(650.0, 920.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  project.projectCode,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  project.projectName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: isArabic ? 'نسخ اسم المشروع' : 'Copy Project Name',
                                child: InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    project.projectName,
                                    customMessage: l10n.copiedToClipboard(project.projectName),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isActive ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isActive ? AppTheme.emerald : AppTheme.crimson,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${_getStatusLabel(context, project.status)} (${isActive ? l10n.statusActive : l10n.statusInactive})',
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${l10n.projectOwnerLabelField.replaceAll('*', '').trim()}: ${project.projectOwner} • ${_getImportTypeLabel(context, project.importType)} • ${_getPriorityLabel(context, project.priority)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      tooltip: l10n.closeBtn,
                    ),
                  ],
                ),
              ),

              // ── Scrollable Body ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Overview & Stakeholders
                      _buildSectionHeader(context, Icons.business_center_outlined, isArabic ? 'بيانات المشروع والشركاء' : 'Project Details & Stakeholders'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.importingCompaniesFieldLabel.replaceAll('*', '').trim(),
                                    value: project.companyName ?? '—',
                                    icon: Icons.domain,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.primarySupplierLabel.replaceAll('*', '').trim(),
                                    value: project.supplierName ?? '—',
                                    icon: Icons.flight_takeoff_rounded,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.defaultIncotermLabel.replaceAll('*', '').trim(),
                                    value: project.incotermCode ?? l10n.projectIncotermFallback,
                                    icon: Icons.handshake_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.projectColShipmentCategories,
                                    value: project.shipmentCategory
                                        .split(',')
                                        .map((c) => _getCategoryLabel(context, c))
                                        .join(', '),
                                    icon: Icons.local_shipping_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: isArabic ? 'أوامر الشراء' : 'Purchase Orders',
                                    value: '${project.poCount ?? 0}',
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Budget & Financial Performance
                      _buildSectionHeader(context, Icons.account_balance_wallet_outlined, isArabic ? 'الموازنة والتحليل المالي' : 'Budget & Financial Analysis'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.emerald.withValues(alpha: 0.08) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppTheme.emerald.withValues(alpha: 0.3) : const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.budgetUsdCol,
                                    value: project.totalBudgetUsd != null
                                        ? '${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}'
                                        : l10n.projectBudgetNotSet,
                                    icon: Icons.monetization_on_outlined,
                                    highlightColor: AppTheme.cobalt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: isArabic ? 'الالتزامات والارتباطات' : 'Committed Budget',
                                    value: project.totalCommittedUsd != null
                                        ? '${project.budgetCurrency} ${project.totalCommittedUsd!.toStringAsFixed(2)}'
                                        : '0.00 ${project.budgetCurrency}',
                                    icon: Icons.lock_clock_outlined,
                                    highlightColor: AppTheme.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: isArabic ? 'المتبقي من الموازنة' : 'Remaining Budget',
                                    value: project.remainingBudgetUsd != null
                                        ? '${project.budgetCurrency} ${project.remainingBudgetUsd!.toStringAsFixed(2)}'
                                        : (project.totalBudgetUsd != null ? '${project.budgetCurrency} ${project.totalBudgetUsd!.toStringAsFixed(2)}' : '—'),
                                    icon: Icons.savings_outlined,
                                    highlightColor: AppTheme.emerald,
                                  ),
                                ),
                              ],
                            ),
                            if (project.budgetUtilizationPercent != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    '${isArabic ? "نسبة استهلاك الموازنة" : "Budget Utilization"}: ${(project.budgetUtilizationPercent! * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: project.budgetUtilizationPercent!.clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade300,
                                        color: project.budgetUtilizationPercent! > 0.9
                                            ? AppTheme.crimson
                                            : (project.budgetUtilizationPercent! > 0.75 ? AppTheme.orange : AppTheme.emerald),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Timeline & Schedule
                      _buildSectionHeader(context, Icons.event_note_outlined, isArabic ? 'الجدول الزمني والملاحظات' : 'Schedule & Notes'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: l10n.targetEndDateLabel,
                                    value: project.targetEndDate ?? '—',
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoField(
                                    context: context,
                                    label: isArabic ? 'تاريخ الإنشاء' : 'Created Date',
                                    value: project.createdAt != null
                                        ? project.createdAt!.toLocal().toString().split(' ').first
                                        : '—',
                                    icon: Icons.history_toggle_off,
                                  ),
                                ),
                              ],
                            ),
                            if (project.notes != null && project.notes!.isNotEmpty) ...[
                              const Divider(height: 18),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  '${l10n.projectNotesLabel}: ${project.notes}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Section 4: Change History & Audit Trail (At Bottom of Dialog) ──
                      _buildSectionHeader(context, Icons.history_edu_rounded, l10n.rowHistoryDialogTitle),
                      const SizedBox(height: 10),
                      _ProjectAuditHistoryView(project: project),
                    ],
                  ),
                ),
              ),

              // ── Action Footer ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: Text(l10n.projectCopySummaryBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        CopyHelper.copy(
                          context,
                          _buildProjectSummary(context),
                          customMessage: l10n.projectCopySummarySuccess,
                        );
                      },
                    ),
                    Row(
                      children: [
                        if (onEdit != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(isArabic ? 'تعديل المشروع' : 'Edit Project', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                onEdit?.call();
                              });
                            },
                          ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.closeBtn),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? highlightColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: highlightColor ?? (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: highlightColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Embedded Audit History Viewer for Project
class _ProjectAuditHistoryView extends ConsumerWidget {
  final ProjectModel project;

  const _ProjectAuditHistoryView({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (project.projectId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(l10n.rowHistoryEmpty, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }

    final timelineAsync = ref.watch(
      entityAuditTimelineProvider((entityType: 'Project', entityId: project.projectId!)),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'حركات وسجل التغييرات المدققة' : 'Audited Change Log',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: l10n.rowHistoryRefreshTooltip,
                  onPressed: () {
                    ref.invalidate(entityAuditTimelineProvider((entityType: 'Project', entityId: project.projectId!)));
                  },
                ),
              ],
            ),
          ),
          timelineAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cobalt)),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.auditLogsFetchError(err.toString()),
                style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          l10n.rowHistoryEmpty,
                          style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color actionColor;
                  IconData actionIcon;
                  switch (log.action.toUpperCase()) {
                    case 'CREATE':
                      actionColor = AppTheme.emerald;
                      actionIcon = Icons.add_circle_outline;
                      break;
                    case 'UPDATE':
                      actionColor = AppTheme.cobalt;
                      actionIcon = Icons.edit_outlined;
                      break;
                    case 'DELETE':
                      actionColor = AppTheme.crimson;
                      actionIcon = Icons.remove_circle_outline;
                      break;
                    default:
                      actionColor = AppTheme.charcoal;
                      actionIcon = Icons.info_outline;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(actionIcon, size: 16, color: actionColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.auditActionLabel(log.action),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: actionColor,
                                  ),
                                ),
                                Text(
                                  log.performedAt.toLocal().toString().split('.').first,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.changesSummary ?? l10n.systemMutationFallback,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.performedByUser(log.performedBy),
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
