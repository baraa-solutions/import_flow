import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Representation of a single modified field in any entity across the ERP system.
class FieldChangeItem {
  final String fieldName;
  final dynamic oldValue;
  final dynamic newValue;
  final String? section;

  FieldChangeItem({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    this.section,
  });

  /// Formats value into a clean, human-readable string.
  static String formatValue(dynamic val) {
    if (val == null) return '(فارغ / غير محدد)';
    if (val is bool) {
      return val ? '📦 قابل للرص (نعم / مفعل)' : '🚫 غير قابل للرص (لا / معطل)';
    }
    final s = val.toString().trim();
    if (s.isEmpty) return '(فارغ / غير محدد)';
    return s;
  }

  /// Checks if two values are actually different.
  static bool isDifferent(dynamic oldVal, dynamic newVal) {
    if (oldVal == null && newVal == null) return false;
    if (oldVal is bool && newVal is bool) return oldVal != newVal;
    if (oldVal is num && newVal is num) return (oldVal - newVal).abs() > 0.0001;
    final sOld = (oldVal?.toString() ?? '').trim();
    final sNew = (newVal?.toString() ?? '').trim();
    return sOld != sNew;
  }
}

/// A centralized, high-contrast modal dialog to review and confirm differences before saving edits.
class ChangeDiffConfirmationDialog extends StatelessWidget {
  final String title;
  final String itemReference;
  final List<FieldChangeItem> changes;
  final String confirmButtonText;

  const ChangeDiffConfirmationDialog({
    super.key,
    required this.title,
    required this.itemReference,
    required this.changes,
    this.confirmButtonText = 'تأكيد وحفظ التعديلات',
  });

  @override
  Widget build(BuildContext context) {
    // Group changes by section if applicable
    final Map<String, List<FieldChangeItem>> groupedChanges = {};
    for (final change in changes) {
      final sec = change.section ?? 'البيانات العامة والأساسية';
      groupedChanges.putIfAbsent(sec, () => []).add(change);
    }

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppTheme.charcoal,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade700.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: const Icon(Icons.rule_folder, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'السجل: $itemReference | تم رصد ${changes.length} تعديلات',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${changes.length} تعديل',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 780,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'يرجى مراجعة وتدقيق القيم السابقة والجديدة قبل اعتماد الحفظ النهائي في قاعدة البيانات.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Grouped Changes Table / Cards
              ...groupedChanges.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open, size: 14, color: AppTheme.charcoal),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(3.0),
                          2: FixedColumnWidth(36),
                          3: FlexColumnWidth(3.0),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          // Table Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  'الحقل / البيان',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.charcoal),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  'القيمة السابقة (قبل التعديل)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.crimson),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                  child: Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  'القيمة الجديدة (بعد التعديل)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.emerald),
                                ),
                              ),
                            ],
                          ),

                          // Table Rows
                          ...entry.value.map((item) {
                            final oldStr = FieldChangeItem.formatValue(item.oldValue);
                            final newStr = FieldChangeItem.formatValue(item.newValue);

                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                              ),
                              children: [
                                // Field Name
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    item.fieldName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                  ),
                                ),

                                // Old Value
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      oldStr,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.red.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),

                                // Arrow
                                const Center(
                                  child: Icon(Icons.arrow_forward, size: 16, color: AppTheme.cobalt),
                                ),

                                // New Value
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      newStr,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.green.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.edit_note, size: 18),
          label: const Text(
            'الرجوع للتعديل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
          label: Text(
            confirmButtonText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Helper function to display the confirmation dialog.
/// Returns true if the user confirmed saving, false if cancelled/returned to edit.
/// If there are no differences in [changes], it returns true immediately.
Future<bool> showChangeDiffConfirmationDialog(
  BuildContext context, {
  required String title,
  required String itemReference,
  required List<FieldChangeItem> changes,
  String confirmButtonText = 'تأكيد وحفظ التعديلات',
}) async {
  if (changes.isEmpty) {
    return true;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ChangeDiffConfirmationDialog(
      title: title,
      itemReference: itemReference,
      changes: changes,
      confirmButtonText: confirmButtonText,
    ),
  );

  return result ?? false;
}
