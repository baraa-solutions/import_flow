import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// 📅 Unified Date Picker Form Field — ImportFlow ERP
///
/// Replaces 50+ manual `showDatePicker` + InkWell + InputDecorator + string
/// formatting patterns across 36 files.
///
/// Usage:
/// ```dart
/// AppDatePickerField(
///   label: l10n.colDocDate,
///   value: _selectedDate,
///   onChanged: (date) => setState(() => _selectedDate = date),
/// )
///
/// // Optional: with first/last date constraints
/// AppDatePickerField(
///   label: l10n.date,
///   value: _expiryDate,
///   firstDate: DateTime.now(),
///   lastDate: DateTime(2035),
///   onChanged: (date) => setState(() => _expiryDate = date),
///   isRequired: true,
/// )
///
/// // Read a string value back:
/// _selectedDate?.toIso8601String().substring(0, 10)  // 'YYYY-MM-DD'
/// ```
class AppDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;
  final bool isRequired;
  final bool allowClear;
  final String? Function(DateTime?)? validator;
  final bool readOnly;
  final String? hint;

  const AppDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.isRequired = false,
    this.allowClear = true,
    this.validator,
    this.readOnly = false,
    this.hint,
  });

  /// Format a [DateTime] as 'YYYY-MM-DD' — ISO 8601 short form.
  static String format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parse 'YYYY-MM-DD' back to [DateTime]. Returns null on failure.
  static DateTime? tryParse(String? s) {
    if (s == null || s.length < 10) return null;
    return DateTime.tryParse(s.substring(0, 10));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final displayText = value != null ? format(value!) : '';
    final effectiveFirst = firstDate ?? DateTime(2000);
    final effectiveLast = lastDate ?? DateTime(2040);

    // Effective validator: checks required constraint, then custom.
    String? effectiveValidator(String? _) {
      if (isRequired && value == null) return l.requiredField;
      if (validator != null) return validator!(value);
      return null;
    }

    return FormField<String>(
      initialValue: displayText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: effectiveValidator,
      builder: (field) {
        final hasError = field.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Label ────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                if (isRequired)
                  const Text(
                    ' *',
                    style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Input ─────────────────────────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: readOnly ? null : () async => _pickDate(context, effectiveFirst, effectiveLast),
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppTheme.surfaceAltOf(context),
                  errorText: hasError ? field.errorText : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.crimson),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.crimson, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                  suffixIcon: allowClear && value != null && !readOnly
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: l.clearSearch,
                          onPressed: () {
                            onChanged(null);
                            field.didChange(null);
                          },
                        )
                      : null,
                ),
                child: Text(
                  displayText.isNotEmpty ? displayText : (hint ?? l.selectDateTooltip),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: displayText.isNotEmpty
                        ? AppTheme.textPrimaryOf(context)
                        : AppTheme.textMutedOf(context),
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime first, DateTime last) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? initialDate ?? DateTime.now(),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
