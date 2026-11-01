import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/smart_task_model.dart';

class SmartTasksExportHelper {
  const SmartTasksExportHelper._();

  static int priorityWeight(String p) {
    switch (p.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  static int resolveRouteIndexForTask(SmartTaskModel task) {
    final phase = task.phaseName ?? '';
    final step = task.stepCode ?? '';
    if (step.contains('STEP_01') || step.contains('STEP_02') || phase.contains('Phase 1')) return 2; // PO
    if (step.contains('STEP_03') || phase.contains('Phase 3')) return 11; // Nafeza ACID
    if (step.contains('STEP_05') || phase.contains('Phase 2')) return 16; // Bank Form 4
    if (step.contains('STEP_08') || phase.contains('Phase 4')) return 18; // CargoX / Draft BL
    if (step.contains('STEP_09') || step.contains('STEP_10') || phase.contains('Phase 5')) return 26; // Cargo Shipping
    if (step.contains('STEP_12') || step.contains('STEP_13') || step.contains('STEP_14') || step.contains('STEP_15') || step.contains('STEP_16') || phase.contains('Phase 6') || phase.contains('Phase 7')) return 27; // Customs Clearance
    if (step.contains('STEP_19') || phase.contains('Phase 8')) return 28; // Warehouse Receiving
    if (step.contains('STEP_21')) return 44; // Demurrage / Empty Return
    if (step.contains('STEP_23') || phase.contains('Phase 9')) return 29; // Landed Cost Settlement
    if (step.contains('STEP_25') || phase.contains('Phase 10')) return 30; // File Closure
    return 1; // Default Import Files
  }

  static String buildSmartTaskRowSummary(
    BuildContext context,
    WidgetRef ref,
    SmartTaskModel task,
  ) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shipments = ref.read(importFilesProvider).value ?? <ImportFileModel>[];
    final cleanTitle = task.displayTitle(context.l10n);
    final cleanDesc = task.displayDescription(context.l10n, shipments: shipments);
    final shipmentTitle = task.importFileCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(task.importFileCode, shipments: shipments, isArabic: isAr)
        : null;

    final b = StringBuffer();
    b.writeln('📋 ${task.taskCode} — $cleanTitle');
    b.writeln('🏷️ ${l.smartTasksColType}: ${DisplayNameResolver.resolveTaskType(task.taskType, isArabic: isAr)}');
    if (cleanDesc.isNotEmpty) {
      b.writeln('📝 ${l.smartTaskFieldDescription}: $cleanDesc');
    }
    if (shipmentTitle != null) {
      b.writeln('📦 ${l.smartTasksColShipment}: $shipmentTitle');
    }
    b.writeln('⚡ ${l.smartTasksColPriority}: ${l.smartTaskPriorityLabel(task.priority)}');
    b.writeln('🔔 ${l.smartTasksColReminder}: ${l.smartTaskReminderTypeLabel(task.reminderType)}');
    if (task.dueDate != null) {
      b.writeln('📅 ${l.smartTasksColDueDate}: ${task.dueDate}');
    }
    b.writeln('🚦 ${l.smartTasksColStatus}: ${DisplayNameResolver.resolveTaskStatus(task.status, isArabic: isAr)}');
    b.writeln('👤 ${l.smartTasksTsvHeaderAssignedUser}: ${task.assignedUser}');
    final notes = task.localizedNotes(l);
    if (notes != null && notes.isNotEmpty) {
      b.writeln('🗒️ ${l.smartTaskFieldNotes}: $notes');
    }
    return b.toString().trim();
  }

  static void copySmartTasksTsv(
    BuildContext context,
    WidgetRef ref,
    List<SmartTaskModel> tasks,
  ) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final shipments = ref.read(importFilesProvider).value ?? <ImportFileModel>[];
    final buffer = StringBuffer();
    buffer.writeln(
      '${l.smartTasksTsvHeaderCode}\t'
      '${l.smartTasksTsvHeaderType}\t'
      '${l.smartTasksTsvHeaderTitle}\t'
      '${l.smartTasksTsvHeaderShipment}\t'
      '${l.smartTasksTsvHeaderPriority}\t'
      '${l.smartTasksTsvHeaderReminder}\t'
      '${l.smartTasksTsvHeaderDueDate}\t'
      '${l.smartTasksTsvHeaderStatus}\t'
      '${l.smartTasksTsvHeaderAssignedUser}\t'
      '${l.smartTasksTsvHeaderDescription}',
    );

    for (final t in tasks) {
      final typeLabel = DisplayNameResolver.resolveTaskType(t.taskType, isArabic: isAr);
      final cleanTitle = t.displayTitle(context.l10n);
      final shipment = t.importFileCode != null
          ? DisplayNameResolver.resolveShipmentTitleByCode(t.importFileCode, shipments: shipments, isArabic: isAr)
          : l.smartTasksGeneralBadge;
      final priority = l.smartTaskPriorityLabel(t.priority);
      final reminder = l.smartTaskReminderTypeLabel(t.reminderType);
      final status = DisplayNameResolver.resolveTaskStatus(t.status, isArabic: isAr);
      final desc = t.displayDescription(context.l10n, shipments: shipments).replaceAll('\t', ' ').replaceAll('\n', ' ');

      buffer.writeln(
        '${t.taskCode}\t'
        '$typeLabel\t'
        '${cleanTitle.replaceAll('\t', ' ')}\t'
        '$shipment\t'
        '$priority\t'
        '$reminder\t'
        '${t.dueDate ?? "-"}\t'
        '$status\t'
        '${t.assignedUser}\t'
        '$desc',
      );
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l.smartTasksExportTsvSuccess,
    );
  }
}
