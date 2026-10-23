import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// 🔍 Standalone Search Field — ImportFlow ERP
///
/// Replaces 72+ manual `TextField` search implementations in dialogs, tabs,
/// and standalone filter areas that cannot use `ActionToolbar`.
///
/// Usage:
/// ```dart
/// AppSearchField(
///   controller: _searchController,
///   hint: l10n.searchByName,
///   onChanged: (query) => setState(() => _query = query),
/// )
///
/// // With auto-focus and custom width
/// AppSearchField(
///   controller: _searchController,
///   autofocus: true,
///   width: 300,
///   onSubmitted: _doSearch,
/// )
/// ```
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double? width;
  final bool autofocus;
  final bool dense;

  const AppSearchField({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.width,
    this.autofocus = false,
    this.dense = true,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final hasText = widget.controller.text.isNotEmpty;

    final field = TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      style: TextStyle(
        fontSize: widget.dense ? 12.5 : 14,
        color: AppTheme.textPrimaryOf(context),
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        hintText: widget.hint ?? l.search,
        hintStyle: TextStyle(
          fontSize: widget.dense ? 12 : 13,
          color: AppTheme.textMutedOf(context),
        ),
        isDense: widget.dense,
        contentPadding: widget.dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAlt,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: widget.dense ? 16 : 20,
          color: AppTheme.textMutedOf(context),
        ),
        suffixIcon: hasText
            ? Tooltip(
                message: l.clearSearch,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.clear_rounded,
                      size: widget.dense ? 14 : 18,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5),
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: field);
    }
    return field;
  }
}
