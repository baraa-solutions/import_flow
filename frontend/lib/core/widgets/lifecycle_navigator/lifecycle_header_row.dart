import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/import_files/models/import_file_model.dart';
import '../../localization/app_localizations.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/shipment_task_formatter.dart';
import '../copyable_data_helper.dart';
import 'lifecycle_constants.dart';

class LifecycleHeaderRow extends ConsumerWidget {
  final ImportFileModel currentFile;
  final List<ImportFileModel> files;
  final bool isAr;
  final AppLocalizations l;

  const LifecycleHeaderRow({
    super.key,
    required this.currentFile,
    required this.files,
    required this.isAr,
    required this.l,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Icon(Icons.alt_route_rounded, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 6),
        Text(
          isAr ? l.aiLifecycleTitle : 'Lifecycle:',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: currentFile.importFileId,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoal,
                ),
                items: files.map((file) {
                  final humanName = ShipmentTaskFormatter.formatShipmentLabel(
                    shipmentName: file.displayName,
                    clientName: file.companyName,
                    fileCode: file.importFileCode,
                  );
                  return DropdownMenuItem<int>(
                    value: file.importFileId,
                    child: Text(
                      humanName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    ref.read(aiAssistantProvider.notifier).selectShipment(newId);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon:
              const Icon(Icons.copy_rounded, size: 15, color: AppTheme.cobalt),
          tooltip: isAr
              ? l.aiLifecycleCopySummaryTooltip
              : 'Copy lifecycle summary',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            final buffer = StringBuffer();
            buffer.writeln(isAr
                ? 'مسار الشحنة: ${currentFile.displayName}'
                : 'Shipment Lifecycle: ${currentFile.displayName}');
            buffer.writeln(isAr
                ? 'كود الملف: ${currentFile.importFileCode}'
                : 'File Code: ${currentFile.importFileCode}');
            buffer.writeln(isAr
                ? 'نسبة الإنجاز: ${(currentFile.progressPercent).round()}%'
                : 'Progress: ${(currentFile.progressPercent).round()}%');
            for (final step in LifecycleConstants.kLifecycleSteps) {
              final sNum = int.tryParse(step['id']!) ?? 1;
              final sName = isAr ? step['nameAr']! : step['nameEn']!;
              final sStatus = sNum <
                      (currentFile.progressPercent / 10).round()
                  ? (isAr ? l.aiLifecycleStatusCompleted : 'Completed')
                  : (sNum == (currentFile.progressPercent / 10).round()
                      ? (isAr ? l.aiLifecycleStatusActive : 'Active')
                      : (isAr ? l.aiLifecycleStatusUpcoming : 'Upcoming'));
              buffer.writeln('$sNum. $sName — $sStatus');
            }
            CopyHelper.copy(context, buffer.toString(),
                customMessage: isAr
                    ? l.aiLifecycleSummaryCopied
                    : 'Lifecycle summary copied to clipboard');
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          tooltip: isAr ? l.aiLifecycleCloseTooltip : 'Close Navigator',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () =>
              ref.read(aiAssistantProvider.notifier).closeNavigator(),
        ),
      ],
    );
  }
}
