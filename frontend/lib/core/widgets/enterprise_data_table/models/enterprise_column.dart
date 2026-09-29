import 'package:flutter/material.dart';

/// Defines a column definition for [EnterpriseDataTable].
class EnterpriseColumn<T> {
  /// Unique identifier for the column (used in preferences & sorting).
  final String id;

  /// Display title in the column header.
  final String title;

  /// Optional tooltip shown on header hover.
  final String? tooltip;

  /// Optional fixed column width in pixels. If null, automatically sized or flexed.
  final double? width;

  /// Optional flex factor when in responsive layout.
  final int flex;

  /// Whether the user can sort this column.
  final bool isSortable;

  /// Custom sort comparison function. If null, uses [exportValue] or [searchValue] lexicographical comparison.
  final int Function(T a, T b)? sortComparator;

  /// Whether this column participates in global text search.
  final bool isSearchable;

  /// Function to extract searchable text from the item for this column.
  final String Function(T item)? searchValue;

  /// Function to extract formatted plain-text value for Excel/CSV export and clipboard copy.
  final String Function(T item)? exportValue;

  /// Builder for rendering the cell widget.
  final Widget Function(BuildContext context, T item, int index) cellBuilder;

  /// Cell content alignment. Defaults to the reading start (left in LTR,
  /// right in RTL); pass a physical [Alignment] only when the side must not
  /// follow the language.
  final AlignmentGeometry alignment;

  /// Numbers, amounts, dates and codes: the cell renders left-to-right even
  /// in Arabic, so "-1,250.00" keeps its minus sign in front and
  /// "10 - 20" is not reversed. The cell position still follows [alignment].
  final bool isNumeric;

  /// Text alignment in the header and cell.
  final TextAlign textAlign;

  /// Initial default visibility of the column.
  final bool isVisible;

  /// If true, the user cannot hide this column via the column visibility picker.
  final bool isLocked;

  const EnterpriseColumn({
    required this.id,
    required this.title,
    required this.cellBuilder,
    this.tooltip,
    this.width,
    this.flex = 1,
    this.isSortable = true,
    this.sortComparator,
    this.isSearchable = true,
    this.searchValue,
    this.exportValue,
    this.alignment = AlignmentDirectional.centerStart,
    this.isNumeric = false,
    this.textAlign = TextAlign.start,
    this.isVisible = true,
    this.isLocked = false,
  });

  /// Creates a copy of this column with modified properties.
  EnterpriseColumn<T> copyWith({
    String? id,
    String? title,
    String? tooltip,
    double? width,
    int? flex,
    bool? isSortable,
    int Function(T a, T b)? sortComparator,
    bool? isSearchable,
    String Function(T item)? searchValue,
    String Function(T item)? exportValue,
    Widget Function(BuildContext context, T item, int index)? cellBuilder,
    AlignmentGeometry? alignment,
    bool? isNumeric,
    TextAlign? textAlign,
    bool? isVisible,
    bool? isLocked,
  }) {
    return EnterpriseColumn<T>(
      id: id ?? this.id,
      title: title ?? this.title,
      tooltip: tooltip ?? this.tooltip,
      width: width ?? this.width,
      flex: flex ?? this.flex,
      isSortable: isSortable ?? this.isSortable,
      sortComparator: sortComparator ?? this.sortComparator,
      isSearchable: isSearchable ?? this.isSearchable,
      searchValue: searchValue ?? this.searchValue,
      exportValue: exportValue ?? this.exportValue,
      cellBuilder: cellBuilder ?? this.cellBuilder,
      alignment: alignment ?? this.alignment,
      isNumeric: isNumeric ?? this.isNumeric,
      textAlign: textAlign ?? this.textAlign,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
