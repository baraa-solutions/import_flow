import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchableDropdownItem<T> {
  final T value;
  final String label;
  final String? searchValue;
  final String? subtitle;
  final IconData? icon;

  const SearchableDropdownItem({
    required this.value,
    required this.label,
    this.searchValue,
    this.subtitle,
    this.icon,
  });
}

class SearchableDropdownField<T> extends FormField<T> {
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String labelText;
  final String? hintText;
  final String? searchHintText;
  final bool isDense;
  final bool isRequired;
  final InputDecoration? decoration;

  SearchableDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText = '',
    this.hintText,
    this.searchHintText,
    this.isDense = true,
    this.isRequired = false,
    super.enabled = true,
    this.decoration,
    super.validator,
    super.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(
          initialValue: value,
          builder: (FormFieldState<T> state) {
            final context = state.context;
            SearchableDropdownItem<T>? selectedItem;
            try {
              selectedItem = items.firstWhere((item) => item.value == value);
            } catch (_) {
              selectedItem = null;
            }

            final hasValue = selectedItem != null || (value != null && value.toString().trim().isNotEmpty);
            final displayText = selectedItem?.label ?? (value != null && value.toString().trim().isNotEmpty ? value.toString() : (hintText ?? ''));

            final effectiveDecoration = (decoration ??
                    InputDecoration(
                      labelText: labelText,
                      hintText: hintText ?? 'اختر...',
                      isDense: isDense,
                    ))
                .copyWith(
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.charcoal),
            );

            return InkWell(
              onTap: state.widget.enabled
                  ? () async {
                      final selection = await showDialog<_DropdownSelection<T>>(
                        context: context,
                        builder: (ctx) => _SearchableDropdownDialog<T>(
                          title: labelText,
                          items: items,
                          selectedValue: value,
                          searchHintText: searchHintText ?? 'بحث...',
                        ),
                      );

                      if (selection != null) {
                        state.didChange(selection.value);
                        onChanged?.call(selection.value);
                      }
                    }
                  : null,
              child: InputDecorator(
                decoration: effectiveDecoration,
                isEmpty: !hasValue,
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasValue ? AppTheme.charcoal : Colors.grey.shade600,
                    fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
}

class _SearchableDropdownDialog<T> extends StatefulWidget {
  final String title;
  final List<SearchableDropdownItem<T>> items;
  final T? selectedValue;
  final String searchHintText;

  const _SearchableDropdownDialog({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.searchHintText,
  });

  @override
  State<_SearchableDropdownDialog<T>> createState() => _SearchableDropdownDialogState<T>();
}

class _SearchableDropdownDialogState<T> extends State<_SearchableDropdownDialog<T>> {
  late TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SearchableDropdownItem<T>> get _filteredItems {
    final effectiveItems = List<SearchableDropdownItem<T>>.from(widget.items);
    if (widget.selectedValue != null && !effectiveItems.any((i) => i.value == widget.selectedValue)) {
      effectiveItems.insert(
        0,
        SearchableDropdownItem<T>(
          value: widget.selectedValue as T,
          label: widget.selectedValue.toString(),
        ),
      );
    }
    if (_query.trim().isEmpty) return effectiveItems;
    final q = _query.trim().toLowerCase();
    return effectiveItems.where((item) {
      final labelMatch = item.label.toLowerCase().contains(q);
      final searchValMatch = item.searchValue?.toLowerCase().contains(q) ?? false;
      final subtitleMatch = item.subtitle?.toLowerCase().contains(q) ?? false;
      return labelMatch || searchValMatch || subtitleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return AlertDialog(
      titlePadding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.5).clamp(320.0, 480.0),
        height: (MediaQuery.of(context).size.height * 0.55).clamp(260.0, 400.0),
        child: Column(
          children: [
            const SizedBox(height: 6),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.searchHintText,
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.cobalt),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  _query = val;
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد نتائج تطابق "$_query"',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final isSelected = item.value == widget.selectedValue;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          selected: isSelected,
                          selectedTileColor: AppTheme.cobalt.withOpacity(0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          leading: item.icon != null
                              ? Icon(item.icon, size: 18, color: isSelected ? AppTheme.cobalt : AppTheme.charcoal)
                              : (isSelected ? const Icon(Icons.check_circle, size: 18, color: AppTheme.cobalt) : null),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.cobalt : AppTheme.charcoal,
                            ),
                          ),
                          subtitle: item.subtitle != null
                              ? Text(
                                  item.subtitle!,
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context, _DropdownSelection<T>(item.value));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownSelection<T> {
  final T value;
  const _DropdownSelection(this.value);
}

