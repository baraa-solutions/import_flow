import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 🎯 Reusable Helper for Table Row-Level Clone (Line Item Duplication - Task E).
///
/// Handles inserting a duplicated row at [sourceIndex + 1], clearing primary key
/// and sensitive columns, appending localized copy suffixes, and triggering
/// user confirmation.
class TableRowCloneHelper {
  /// Appended to the cloned title. Language-independent on purpose: the value
  /// is saved to the database.
  static const String copySuffix = ' (Copy)';

  /// Appended to cloned business codes (item code, PO number, reference no.).
  /// Language-independent and free of spaces/brackets so the code stays a code.
  static const String copyCodeSuffix = '-COPY';

  /// `'$text (Copy)'`; null/blank input stays as is (null or the blank text).
  static String? withCopySuffix(String? text) =>
      (text == null || text.trim().isEmpty) ? text : '$text$copySuffix';

  /// `'$code-COPY'`; null/blank input stays as is (null or the blank code).
  static String? withCodeSuffix(String? code) =>
      (code == null || code.trim().isEmpty) ? code : '$code$copyCodeSuffix';

  /// Duplicates a map-based row item at [sourceIndex] and inserts it at [sourceIndex + 1].
  ///
  /// - [keysToReset]: Keys that will be set to `null` on the cloned copy (e.g. `['id', 'item_id']`).
  /// - [titleKey]: Optional string field to append [copySuffix] to. The suffix is
  ///   stored with the record, so it is the same in every UI language (business
  ///   references stay English in the database).
  /// - [customizeClonedItem]: Optional hook to adjust values (e.g. recalculate line number).
  static void cloneMapRow({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    required int sourceIndex,
    required VoidCallback onListUpdated,
    List<String> keysToReset = const ['id', 'item_id', 'line_id'],
    String? titleKey,
    void Function(Map<String, dynamic> clonedItem)? customizeClonedItem,
  }) {
    if (sourceIndex < 0 || sourceIndex >= items.length) return;
    final orig = items[sourceIndex];
    final cloned = Map<String, dynamic>.from(orig);

    for (final k in keysToReset) {
      cloned[k] = null;
    }

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (titleKey != null && cloned.containsKey(titleKey) && cloned[titleKey] != null) {
      cloned[titleKey] = '${cloned[titleKey]}$copySuffix';
    }

    customizeClonedItem?.call(cloned);

    items.insert(sourceIndex + 1, cloned);
    onListUpdated();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? '✨ تم استنساخ السطر بنجاح (كنترول + د)'
                : '✨ Row cloned successfully (Ctrl+D)',
          ),
          backgroundColor: AppTheme.wcagCobalt,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
