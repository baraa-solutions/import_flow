import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

/// Specification for a column in [PagedDataTable].
class PagedTableColumn<T> {
  /// Stable unique identifier used for persisting column widths, visibility, and ordering.
  final String id;

  /// Localized title function.
  final String Function(AppLocalizations l) label;

  /// Default / initial column width. Header and cell widths match strictly.
  final double width;

  /// Minimum column width when resizing.
  final double minWidth;

  /// Backend sort field key (e.g. 'code', 'created_at'). Null if column is not sortable.
  final String? sortKey;

  /// If true, content is end-aligned and wrapped in an LTR island for numbers, codes, dates.
  final bool numeric;

  /// If true, column is pinned at the start edge (e.g. actions, selection, primary code).
  final bool pinned;

  /// Whether the column can be hidden via the column picker.
  final bool hideable;

  /// Builder for rendering the cell widget.
  final Widget Function(BuildContext context, T row) cell;

  /// Optional text extractor used for CSV, TSV (Ctrl+C), and Excel export.
  final String Function(T row)? exportValue;

  const PagedTableColumn({
    required this.id,
    required this.label,
    this.width = 150.0,
    this.minWidth = 60.0,
    this.sortKey,
    this.numeric = false,
    this.pinned = false,
    this.hideable = true,
    required this.cell,
    this.exportValue,
  });

  PagedTableColumn<T> copyWith({
    String? id,
    String Function(AppLocalizations l)? label,
    double? width,
    double? minWidth,
    String? sortKey,
    bool? numeric,
    bool? pinned,
    bool? hideable,
    Widget Function(BuildContext context, T row)? cell,
    String Function(T row)? exportValue,
  }) {
    return PagedTableColumn<T>(
      id: id ?? this.id,
      label: label ?? this.label,
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      sortKey: sortKey ?? this.sortKey,
      numeric: numeric ?? this.numeric,
      pinned: pinned ?? this.pinned,
      hideable: hideable ?? this.hideable,
      cell: cell ?? this.cell,
      exportValue: exportValue ?? this.exportValue,
    );
  }
}
