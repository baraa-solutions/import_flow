import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../smart_tasks/models/smart_task_model.dart';

enum DashboardCardType {
  todaysTasks,
  pendingTasks,
  upcomingShipments,
  arrivingThisWeek,
  etaChanges,
  waitingForPayment,
  waitingForForm4,
  pendingRequirements,
  highPriorityAlerts,
}

class DrillDownItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? shipmentCode;
  final String? shipmentTitle;
  final String who;
  final String byWhen;
  final String status;
  final String? statusColorType; // info, warning, danger, success
  final String? nextAction;
  final String? amount;
  final List<String> dataGaps;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;

  DrillDownItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.shipmentCode,
    this.shipmentTitle,
    required this.who,
    required this.byWhen,
    required this.status,
    this.statusColorType,
    this.nextAction,
    this.amount,
    this.dataGaps = const [],
    this.onAction,
    this.actionLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
  });
}

class DashboardDrillDownHelper {
  static List<DrillDownItem> getRecords({
    required DashboardCardType type,
    required List<ImportFileModel> shipments,
    required List<SmartTaskModel> tasks,
    required bool isArabic,
    required AppLocalizations l,
    void Function(String shipmentCode)? onFocusShipment,
    void Function(int taskId)? onCompleteTask,
    void Function(ImportFileModel shipment)? onDailyUpdate,
  }) {
    switch (type) {
      case DashboardCardType.todaysTasks:
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        final filtered = tasks.where((t) {
          final d = t.dueDate;
          final isToday = d != null && (d == todayStr || d.startsWith(todayStr));
          return isToday && t.status != 'Completed' && t.status != 'Cancelled';
        }).toList();

        return filtered.map((t) {
          final shipmentName = t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentNameByCode(
                  t.importFileCode,
                  shipments: shipments,
                  isArabic: isArabic,
                )
              : null;
          return DrillDownItem(
            id: t.taskId.toString(),
            title: t.displayTitle(l),
            subtitle: DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isArabic),
            shipmentCode: t.importFileCode,
            shipmentTitle: shipmentName,
            who: t.assignedUser.isNotEmpty ? t.assignedUser : (isArabic ? 'كمال' : 'Kamal'),
            byWhen: t.dueDate ?? (isArabic ? 'اليوم' : 'Today'),
            status: DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isArabic),
            statusColorType: 'info',
            nextAction: t.displayDescription(l, shipments: shipments, orNotes: true),
            dataGaps: [l.drillDownTimeDataGap],
            actionLabel: onCompleteTask != null ? l.drillDownActionCompleteTask : null,
            onAction: onCompleteTask != null ? () => onCompleteTask(t.taskId) : null,
            secondaryActionLabel: (onFocusShipment != null && t.importFileCode != null)
                ? l.drillDownActionFocusShipment
                : null,
            onSecondaryAction: (onFocusShipment != null && t.importFileCode != null)
                ? () => onFocusShipment(t.importFileCode!)
                : null,
          );
        }).toList();

      case DashboardCardType.pendingTasks:
        final filtered = tasks.where((t) => t.status == 'Pending' || t.status == 'In Progress').toList();

        return filtered.map((t) {
          final shipmentName = t.importFileCode != null
              ? DisplayNameResolver.resolveShipmentNameByCode(
                  t.importFileCode,
                  shipments: shipments,
                  isArabic: isArabic,
                )
              : null;
          return DrillDownItem(
            id: t.taskId.toString(),
            title: t.displayTitle(l),
            subtitle: DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isArabic),
            shipmentCode: t.importFileCode,
            shipmentTitle: shipmentName,
            who: t.assignedUser.isNotEmpty ? t.assignedUser : (isArabic ? 'كمال' : 'Kamal'),
            byWhen: t.dueDate != null && t.dueDate!.isNotEmpty
                ? t.dueDate!
                : (isArabic ? 'غير محدد' : 'Unspecified'),
            status: DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isArabic),
            statusColorType: 'warning',
            nextAction: t.displayDescription(l, shipments: shipments, orNotes: true),
            dataGaps: [l.drillDownPendingReasonDataGap],
            actionLabel: onCompleteTask != null ? l.drillDownActionCompleteTask : null,
            onAction: onCompleteTask != null ? () => onCompleteTask(t.taskId) : null,
            secondaryActionLabel: (onFocusShipment != null && t.importFileCode != null)
                ? l.drillDownActionFocusShipment
                : null,
            onSecondaryAction: (onFocusShipment != null && t.importFileCode != null)
                ? () => onFocusShipment(t.importFileCode!)
                : null,
          );
        }).toList();

      case DashboardCardType.upcomingShipments:
        final filtered = shipments.where((s) => s.status != 'Closed').toList();

        return filtered.map((s) {
          final title = DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic);
          final companyPart = s.companyName.isNotEmpty ? s.companyName : '';
          final supplierPart = s.supplierName.isNotEmpty ? s.supplierName : '';
          final subtitle = [companyPart, supplierPart].where((x) => x.isNotEmpty).join(' • ');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: title,
            subtitle: subtitle.isNotEmpty ? subtitle : null,
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner.isNotEmpty ? s.owner : 'Kamal'} • ${isArabic ? 'المخلص' : 'Broker'}: ${s.brokerName != null && s.brokerName!.isNotEmpty ? s.brokerName! : (isArabic ? 'غير محدد' : 'Unassigned')}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? '${isArabic ? "وصول متوقع" : "ETA"}: ${s.requiredEta}'
                : (isArabic ? 'موعد الوصول قيد التنسيق' : 'ETA pending scheduling'),
            status: (s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic)),
            statusColorType: 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.arrivingThisWeek:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.requiredEta != null ||
                  s.currentModule.toString().contains('Phase 5') ||
                  s.currentModule.toString().contains('Phase 4'));
        }).toList();

        return filtered.map((s) {
          final vessel = s.selectedScenario != null && s.selectedScenario!.isNotEmpty
              ? s.selectedScenario!
              : (isArabic ? 'قيد التحديد' : 'TBD');
          final port = s.portOfDischarge != null && s.portOfDischarge!.isNotEmpty
              ? s.portOfDischarge!
              : (isArabic ? 'غير محدد' : 'Unspecified');

          String clearanceStatus;
          if (s.isCustomsReleased) {
            clearanceStatus = isArabic ? 'مفرج جمركياً' : 'Customs Released';
          } else if (s.form46No != null && s.form46No!.isNotEmpty) {
            clearanceStatus = isArabic ? 'إقرار 46 مسجل' : 'Form 46 Registered';
          } else {
            clearanceStatus = isArabic ? 'قيد الوصول والتخليص' : 'Pending Arrival/Clearance';
          }

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'الناقل/الباخرة' : 'Vessel/Carrier'}: $vessel • ${isArabic ? 'ميناء التفريغ' : 'Port'}: $port',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner} • ${isArabic ? 'المخلص' : 'Broker'}: ${s.brokerName ?? (isArabic ? 'غير محدد' : 'Unassigned')}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? s.requiredEta!
                : (isArabic ? 'خلال هذا الأسبوع' : 'This week'),
            status: clearanceStatus,
            statusColorType: s.isCustomsReleased ? 'success' : 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownTimeDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.etaChanges:
        final filtered = shipments.where((s) => s.status != 'Closed' && s.requiredEta != null).toList();

        return filtered.map((s) {
          final carrier = s.selectedScenario != null && s.selectedScenario!.isNotEmpty
              ? s.selectedScenario!
              : (isArabic ? 'غير محدد' : 'Unassigned');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'الخط الملاحي' : 'Carrier'}: $carrier • ${s.portOfDischarge ?? ''}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'مسؤول الملف' : 'Owner'}: ${s.owner}',
            byWhen: '${isArabic ? 'تاريخ الوصول الفعلي' : 'Recorded ETA'}: ${s.requiredEta}',
            status: isArabic ? 'تاريخ ETA معتمد' : 'Confirmed ETA',
            statusColorType: 'info',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownEtaChangeDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.waitingForPayment:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.currentModule.toString().contains('Phase 2') ||
                  (s.estimatedCost > 0 && (s.form4No == null || s.form4No!.trim().isEmpty)));
        }).toList();

        return filtered.map((s) {
          final amountFormatted = '${s.estimatedCost.toStringAsFixed(2)} ${s.estimatedCostCurrency}';
          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'المبلغ المطلوب' : 'Amount'}: $amountFormatted • ${isArabic ? 'المورد' : 'Supplier'}: ${s.supplierName}',
            amount: amountFormatted,
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول المالي' : 'Finance Officer'}: ${s.owner.isNotEmpty ? s.owner : 'Kamal'}',
            byWhen: s.cargoReadyDate != null && s.cargoReadyDate!.isNotEmpty
                ? '${isArabic ? "جاهزية البضاعة" : "Cargo Ready"}: ${s.cargoReadyDate}'
                : (isArabic ? 'بانتظار الموافقة وصرف الدفعة' : 'Awaiting Payment Approval'),
            status: isArabic ? 'بانتظار الاعتماد المالي وصرف الدفعة' : 'Awaiting Budget Approval',
            statusColorType: 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: [l.drillDownPaymentDeadlineDataGap],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.waitingForForm4:
        final filtered = shipments.where((s) => s.status != 'Closed' && (s.form4No == null || s.form4No!.trim().isEmpty)).toList();

        return filtered.map((s) {
          final swift = s.swiftNo != null && s.swiftNo!.isNotEmpty
              ? 'SWIFT: ${s.swiftNo}'
              : (isArabic ? 'قيد التقديم بالبنك' : 'Pending Bank Issuance');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'البنك' : 'Bank'}: $swift • ${isArabic ? 'الشركة المستوردة' : 'Company'}: ${s.companyName}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'مسؤول الاعتماد البنكي' : 'Banking Specialist'}: ${s.owner}',
            byWhen: s.form4RequestDate != null && s.form4RequestDate!.isNotEmpty
                ? '${isArabic ? "تاريخ الطلب" : "Request Date"}: ${s.form4RequestDate}'
                : (isArabic ? 'لم يتم تقديم الطلب بعد' : 'Not yet submitted'),
            status: isArabic ? 'نموذج 4 معلق' : 'Form 4 Pending',
            statusColorType: 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.pendingRequirements:
        final filtered = shipments.where((s) {
          return s.status != 'Closed' &&
              (s.acidNumber == null || s.acidNumber!.trim().isEmpty || s.form46No == null || s.form46No!.trim().isEmpty);
        }).toList();

        return filtered.map((s) {
          final List<String> missing = [];
          if (s.acidNumber == null || s.acidNumber!.trim().isEmpty) {
            missing.add(isArabic ? 'رقم ACID نافذة (19 رقم)' : 'Nafeza ACID Number');
          }
          if (s.form46No == null || s.form46No!.trim().isEmpty) {
            missing.add(isArabic ? 'إقرار 46 ك.م جمركي' : 'Form 46 KM Declaration');
          }
          final missingDesc = missing.join(' • ');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '${isArabic ? 'المتطلب الناقص' : 'Missing'}: $missingDesc',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المخلص/منسق نافذة' : 'Broker/Nafeza'}: ${s.brokerName ?? (isArabic ? 'غير محدد' : 'Unassigned')} • ${s.owner}',
            byWhen: '${isArabic ? 'معلق منذ' : 'Pending since'}: ${s.createdAt.contains('T') ? s.createdAt.split('T').first : s.createdAt}',
            status: isArabic ? 'متطلبات إجرائية غير مكتملة' : 'Incomplete Requirements',
            statusColorType: 'danger',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();

      case DashboardCardType.highPriorityAlerts:
        final filtered = shipments.where((s) => s.status != 'Closed' && (s.priority == 'High' || s.priority == 'Critical')).toList();

        return filtered.map((s) {
          final isCrit = s.priority == 'Critical';
          final prioText = isCrit
              ? (isArabic ? 'أولوية حرجة للغاية' : 'Critical Priority')
              : (isArabic ? 'أولوية عالية' : 'High Priority');

          return DrillDownItem(
            id: s.importFileId.toString(),
            title: DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic),
            subtitle: '$prioText • ${(s.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(s.currentModule, isArabic: isArabic))}',
            shipmentCode: s.importFileCode,
            shipmentTitle: DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
            who: '${isArabic ? 'المسؤول' : 'Owner'}: ${s.owner}',
            byWhen: s.requiredEta != null && s.requiredEta!.isNotEmpty
                ? '${isArabic ? "وصول" : "ETA"}: ${s.requiredEta}'
                : (isArabic ? 'إجراء عاجل وفوري' : 'Immediate Action Required'),
            status: s.priority,
            statusColorType: isCrit ? 'danger' : 'warning',
            nextAction: s.displayNextAction(l),
            dataGaps: const [],
            actionLabel: onFocusShipment != null ? l.drillDownActionFocusShipment : null,
            onAction: onFocusShipment != null ? () => onFocusShipment(s.importFileCode) : null,
            secondaryActionLabel: onDailyUpdate != null ? l.drillDownActionDailyUpdate : null,
            onSecondaryAction: onDailyUpdate != null ? () => onDailyUpdate(s) : null,
          );
        }).toList();
    }
  }
}

class DashboardCardDrillDownDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<DrillDownItem> records;
  final bool isArabic;

  const DashboardCardDrillDownDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.records,
    required this.isArabic,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color themeColor,
    required List<DrillDownItem> records,
    required bool isArabic,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DashboardCardDrillDownDialog(
        title: title,
        icon: icon,
        themeColor: themeColor,
        records: records,
        isArabic: isArabic,
      ),
    );
  }

  /// Formats the shipment display for badges and copy outputs, ensuring zero duplication.
  static String formatBadgeShipment(DrillDownItem item) {
    final code = item.shipmentCode;
    final title = item.shipmentTitle;
    if (code == null || code.trim().isEmpty) return title ?? '-';
    final trimmedCode = code.trim();
    if (title == null || title.trim().isEmpty || title.trim() == trimmedCode) {
      return trimmedCode;
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.contains(trimmedCode)) {
      return trimmedTitle;
    }
    return '$trimmedTitle ($trimmedCode)';
  }

  @override
  State<DashboardCardDrillDownDialog> createState() => _DashboardCardDrillDownDialogState();
}

class _DashboardCardDrillDownDialogState extends State<DashboardCardDrillDownDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DrillDownItem> get _filteredRecords {
    if (_searchQuery.trim().isEmpty) return widget.records;
    final q = _searchQuery.trim().toLowerCase();
    return widget.records.where((item) {
      final t = item.title.toLowerCase();
      final sub = item.subtitle?.toLowerCase() ?? '';
      final code = item.shipmentCode?.toLowerCase() ?? '';
      final sTitle = item.shipmentTitle?.toLowerCase() ?? '';
      final who = item.who.toLowerCase();
      final status = item.status.toLowerCase();
      final when = item.byWhen.toLowerCase();
      return t.contains(q) ||
          sub.contains(q) ||
          code.contains(q) ||
          sTitle.contains(q) ||
          who.contains(q) ||
          status.contains(q) ||
          when.contains(q);
    }).toList();
  }

  void _copyAllRecords(BuildContext context, AppLocalizations l) {
    final buffer = StringBuffer();
    buffer.writeln('=== ${widget.title} (${widget.records.length} ${l.drillDownItemsCountSuffix}) ===\n');

    for (int i = 0; i < widget.records.length; i++) {
      final r = widget.records[i];
      buffer.writeln('${i + 1}. ${r.title}');
      if (r.shipmentCode != null) {
        buffer.writeln('   - ${widget.isArabic ? "الشحنة" : "Shipment"}: ${DashboardCardDrillDownDialog.formatBadgeShipment(r)}');
      }
      buffer.writeln('   - ${l.drillDownLabelWhat}: ${r.nextAction ?? r.subtitle ?? r.title}');
      buffer.writeln('   - ${l.drillDownLabelWho}: ${r.who}');
      buffer.writeln('   - ${l.drillDownLabelWhen}: ${r.byWhen}');
      buffer.writeln('   - ${l.drillDownLabelStatus}: ${r.status}');
      if (r.dataGaps.isNotEmpty) {
        buffer.writeln('   - [${l.drillDownDataGapBadge}]: ${r.dataGaps.join(" | ")}');
      }
      buffer.writeln();
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l.drillDownCopiedAllToast);
  }

  void _copySingleRecord(BuildContext context, DrillDownItem r, AppLocalizations l) {
    final buffer = StringBuffer();
    buffer.writeln(r.title);
    if (r.shipmentCode != null) {
      buffer.writeln('${widget.isArabic ? "الشحنة" : "Shipment"}: ${DashboardCardDrillDownDialog.formatBadgeShipment(r)}');
    }
    buffer.writeln('${l.drillDownLabelWhat}: ${r.nextAction ?? r.subtitle ?? r.title}');
    buffer.writeln('${l.drillDownLabelWho}: ${r.who}');
    buffer.writeln('${l.drillDownLabelWhen}: ${r.byWhen}');
    buffer.writeln('${l.drillDownLabelStatus}: ${r.status}');
    if (r.dataGaps.isNotEmpty) {
      buffer.writeln('[${l.drillDownDataGapBadge}]: ${r.dataGaps.join(" | ")}');
    }

    CopyHelper.copy(context, buffer.toString(), customMessage: l.drillDownCopiedItemToast);
  }

  Color _getStatusColor(String? type) {
    switch (type) {
      case 'danger':
        return AppTheme.crimson;
      case 'warning':
        return AppTheme.orange;
      case 'success':
        return AppTheme.emerald;
      case 'info':
      default:
        return AppTheme.cobalt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final totalCount = widget.records.length;
    final displayedList = _filteredRecords;
    final isDark = AppTheme.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
      ),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: SelectionArea(
        child: Container(
          width: 880,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: isDark ? 0.15 : 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.themeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalCount ${l.drillDownItemsCountSuffix}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalCount > 0) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : widget.themeColor,
                        side: BorderSide(color: widget.themeColor.withValues(alpha: isDark ? 0.7 : 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: Text(
                        l.drillDownCopyAllBtn,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _copyAllRecords(context, l),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                    tooltip: l.drillDownCloseBtn,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Search & Filter Bar ────────────────────────────────────────
            if (totalCount > 0)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: l.drillDownSearchHint,
                    hintStyle: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                  ),
                ),
              ),

            // ── Records List or Empty State ────────────────────────────────
            Expanded(
              child: totalCount == 0
                  ? _buildEmptyState(context, l, isDark: isDark)
                  : displayedList.isEmpty
                      ? Center(
                          child: Text(
                            widget.isArabic
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'No items match your search query',
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: displayedList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final item = displayedList[index];
                            return _buildRecordCard(context, item, l, isDark: isDark);
                          },
                        ),
            ),

            // ── Dialog Footer ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l.drillDownItemsCountSuffix}: ${displayedList.length} / $totalCount',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l.drillDownCloseBtn,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
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

  Widget _buildEmptyState(BuildContext context, AppLocalizations l, {bool isDark = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt_rounded, size: 48, color: widget.themeColor),
            ),
            const SizedBox(height: 16),
            Text(
              l.drillDownEmptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                l.drillDownEmptyDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, DrillDownItem item, AppLocalizations l, {bool isDark = false}) {
    final statusColor = _getStatusColor(item.statusColorType);

    return Card(
      elevation: 1.5,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title + Status + Copy Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CopyableText(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: isDark ? 0.6 : 0.4)),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: isDark ? Colors.tealAccent.shade100 : statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 16, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                  tooltip: l.drillDownCopiedItemToast,
                  onPressed: () => _copySingleRecord(context, item, l),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),

            if (item.shipmentCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: isDark ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                    const SizedBox(width: 6),
                    Text(
                      DashboardCardDrillDownDialog.formatBadgeShipment(item),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Divider(height: 20, color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E0E0)),

            // Middle Grid: What / Who / By When
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildInfoBlock(
                  icon: Icons.checklist_rtl_rounded,
                  label: l.drillDownLabelWhat,
                  value: item.nextAction ?? item.title,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  isDark: isDark,
                ),
                _buildInfoBlock(
                  icon: Icons.person_outline_rounded,
                  label: l.drillDownLabelWho,
                  value: item.who,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  isDark: isDark,
                ),
                _buildInfoBlock(
                  icon: Icons.event_available_rounded,
                  label: l.drillDownLabelWhen,
                  value: item.byWhen,
                  color: isDark ? Colors.orange.shade300 : AppTheme.orange,
                  isDark: isDark,
                ),
              ],
            ),

            // Data Gaps Alert (Explicitly logged to user)
            if (item.dataGaps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 15, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: item.dataGaps.map((gap) {
                          return Text(
                            '⚠️ ${l.drillDownDataGapBadge}: $gap',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons Row
            if (item.onAction != null || item.onSecondaryAction != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.onSecondaryAction != null && item.secondaryActionLabel != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                        side: BorderSide(color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.touch_app_rounded, size: 14),
                      label: Text(
                        item.secondaryActionLabel!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        item.onSecondaryAction!();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.onAction != null && item.actionLabel != null) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      label: Text(
                        item.actionLabel!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        item.onAction!();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isDark = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                CopyableText(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  showIcon: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
