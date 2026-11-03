import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_documentation/screens/bank_form4_screen.dart';
import '../../import_files/models/import_file_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Documents section card (ACID, Form 4, SWIFT, Form 46) for Comprehensive Report.
class ReportDocumentsCard extends StatelessWidget {
  final ImportFileModel file;
  final VoidCallback? onOpenForm4;

  const ReportDocumentsCard({
    super.key,
    required this.file,
    this.onOpenForm4,
  });

  static void openBankForm4Dialog(BuildContext context, ImportFileModel file) {
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 1050,
          height: 720,
          child: Stack(
            children: [
              BankForm4Screen(
                initialImportFileId: file.importFileId,
                initialSubTab: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING') ? 1 : 0,
              ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isForm4Pending = file.form4No == null ||
        file.form4No!.isEmpty ||
        file.form4No == '—' ||
        file.form4No == 'PENDING';

    final docs = <Map<String, dynamic>>[
      {
        'key': 'acid',
        'label': l.compReportAcidNumber,
        'value': file.acidNumber ?? '—',
        'isPending': file.acidNumber == null || file.acidNumber!.isEmpty || file.acidNumber == '—',
      },
      {
        'key': 'form4',
        'label': l.compReportBankForm4,
        'value': file.form4No ?? '—',
        'isPending': isForm4Pending,
      },
      {
        'key': 'swift',
        'label': l.compReportSwiftNumber,
        'value': file.swiftNo ?? '—',
        'isPending': file.swiftNo == null || file.swiftNo!.isEmpty || file.swiftNo == '—',
      },
      {
        'key': 'form46',
        'label': l.compReportForm46Number,
        'value': file.form46No ?? '—',
        'isPending': file.form46No == null || file.form46No!.isEmpty || file.form46No == '—',
      },
    ];

    return ReportCardContainer(
      title: l.compReportSecDocs,
      icon: Icons.description_outlined,
      iconColor: AppTheme.orange,
      child: Column(
        children: docs.map((d) {
          final key = d['key'] as String;
          final val = d['value'] as String;
          final isPending = d['isPending'] as bool;
          final hasValue = !isPending;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(
                  hasValue ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                  size: 16,
                  color: hasValue ? AppTheme.emerald : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d['label'] as String,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                if (key == 'form4' && isPending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'معلق',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'فتح ديالوج نموذج 4 البنكي لمتابعة وتوثيق الطلب',
                    child: ElevatedButton.icon(
                      key: const Key('openForm4DialogQuickBtn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 26),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 12),
                      label: const Text(
                        'فتح نموذج 4',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onOpenForm4 ?? () => openBankForm4Dialog(context, file),
                    ),
                  ),
                ] else if (hasValue) ...[
                  ReportCopyBadge(
                    textToCopy: val,
                    color: Colors.green.shade50,
                    borderColor: Colors.green.shade200,
                    textColor: Colors.green.shade800,
                  ),
                  if (key == 'form4') ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 14, color: AppTheme.cobalt),
                      tooltip: 'عرض وتعديل نموذج 4 البنكي',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: onOpenForm4 ?? () => openBankForm4Dialog(context, file),
                    ),
                  ],
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      val,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
