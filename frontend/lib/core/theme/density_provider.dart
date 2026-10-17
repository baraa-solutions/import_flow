import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Display density levels for ERP data tables and form grids.
/// Persisted via FlutterSecureStorage so user preference is remembered across sessions.
enum DisplayDensityMode {
  comfortable(
    nameAr: 'مريح',
    nameEn: 'Comfortable',
    rowHeight: 56.0,
    headerHeight: 46.0,
    fontSizeDelta: 0.0,
    // Buttons & Icons
    buttonHeight: 36.0,
    buttonPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    buttonFontSize: 13.0,
    buttonIconSize: 16.0,
    // Header
    headerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    headerTitleFontSize: 20.0,
    headerSubtitleFontSize: 13.0,
    headerIconSize: 22.0,
    // Toolbar & Inputs
    toolbarHeight: 40.0,
    inputFontSize: 13.0,
    // Metrics
    metricCardHeight: 42.0,
    metricCardPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    metricTitleFontSize: 14.0,
    metricValueFontSize: 14.0,
    metricIconSize: 17.0,
    // Table Typography
    tableHeaderFontSize: 13.0,
    tableCellPrimaryFontSize: 14.0,
    tableCellSecondaryFontSize: 12.0,
    // Navigation
    sidebarNavFontSize: 13.0,
    // Workspace & Top Bar
    topBarHeight: 44.0,
    tabBarHeight: 30.0,
    tableRowHeight: 52.0,
    tableHeadingHeight: 44.0,
    contentPadding: EdgeInsets.all(16.0),
  ),
  compact(
    nameAr: 'مدمج',
    nameEn: 'Compact',
    rowHeight: 48.0,
    headerHeight: 42.0,
    fontSizeDelta: -0.5,
    // Buttons & Icons
    buttonHeight: 32.0,
    buttonPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    buttonFontSize: 12.0,
    buttonIconSize: 15.0,
    // Header
    headerPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    headerTitleFontSize: 17.0,
    headerSubtitleFontSize: 12.0,
    headerIconSize: 20.0,
    // Toolbar & Inputs
    toolbarHeight: 36.0,
    inputFontSize: 12.0,
    // Metrics
    metricCardHeight: 34.0,
    metricCardPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    metricTitleFontSize: 13.0,
    metricValueFontSize: 13.0,
    metricIconSize: 15.5,
    // Table Typography
    tableHeaderFontSize: 12.0,
    tableCellPrimaryFontSize: 13.0,
    tableCellSecondaryFontSize: 11.0,
    // Navigation
    sidebarNavFontSize: 13.0,
    // Workspace & Top Bar
    topBarHeight: 38.0,
    tabBarHeight: 28.0,
    tableRowHeight: 42.0,
    tableHeadingHeight: 38.0,
    contentPadding: EdgeInsets.all(10.0),
  ),
  ultraCompact(
    nameAr: 'فائق الكثافة',
    nameEn: 'Ultra-Compact',
    rowHeight: 40.0,
    headerHeight: 38.0,
    fontSizeDelta: -1.0,
    // Buttons & Icons
    buttonHeight: 28.0,
    buttonPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    buttonFontSize: 12.0,
    buttonIconSize: 14.0,
    // Header
    headerPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    headerTitleFontSize: 15.0,
    headerSubtitleFontSize: 11.0,
    headerIconSize: 18.0,
    // Toolbar & Inputs
    toolbarHeight: 30.0,
    inputFontSize: 12.0,
    // Metrics
    metricCardHeight: 28.0,
    metricCardPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    metricTitleFontSize: 12.0,
    metricValueFontSize: 12.0,
    metricIconSize: 14.0,
    // Table Typography
    tableHeaderFontSize: 12.0,
    tableCellPrimaryFontSize: 12.0,
    tableCellSecondaryFontSize: 11.0,
    // Navigation
    sidebarNavFontSize: 12.0,
    // Workspace & Top Bar
    topBarHeight: 32.0,
    tabBarHeight: 26.0,
    tableRowHeight: 34.0,
    tableHeadingHeight: 32.0,
    contentPadding: EdgeInsets.all(6.0),
  );

  final String nameAr;
  final String nameEn;
  final double rowHeight;
  final double headerHeight;
  final double fontSizeDelta;
  final double buttonHeight;
  final EdgeInsets buttonPadding;
  final double buttonFontSize;
  final double buttonIconSize;
  final EdgeInsets headerPadding;
  final double headerTitleFontSize;
  final double headerSubtitleFontSize;
  final double headerIconSize;
  final double toolbarHeight;
  final double inputFontSize;
  final double metricCardHeight;
  final EdgeInsets metricCardPadding;
  final double metricTitleFontSize;
  final double metricValueFontSize;
  final double metricIconSize;
  final double tableHeaderFontSize;
  final double tableCellPrimaryFontSize;
  final double tableCellSecondaryFontSize;
  final double sidebarNavFontSize;
  final double topBarHeight;
  final double tabBarHeight;
  final double tableRowHeight;
  final double tableHeadingHeight;
  final EdgeInsets contentPadding;

  /// Strict floor rule: no text in the system may drop below 11px.
  static double clampFontSize(double size) => size < 11.0 ? 11.0 : size;

  bool get isComfortable => this == DisplayDensityMode.comfortable;
  bool get isCompact => this == DisplayDensityMode.compact;
  bool get isUltraCompact => this == DisplayDensityMode.ultraCompact;

  /// Picks the value matching this density mode.
  T byDensity<T>(T comfortable, T compact, T ultra) {
    switch (this) {
      case DisplayDensityMode.comfortable:
        return comfortable;
      case DisplayDensityMode.compact:
        return compact;
      case DisplayDensityMode.ultraCompact:
        return ultra;
    }
  }

  String localizedName(bool isArabic) => isArabic ? nameAr : nameEn;

  VisualDensity get visualDensity {
    switch (this) {
      case DisplayDensityMode.comfortable:
        return VisualDensity.standard;
      case DisplayDensityMode.compact:
        return VisualDensity.compact;
      case DisplayDensityMode.ultraCompact:
        return const VisualDensity(horizontal: -3, vertical: -3);
    }
  }

  EdgeInsets get cardPadding {
    switch (this) {
      case DisplayDensityMode.comfortable:
        return const EdgeInsets.all(14.0);
      case DisplayDensityMode.compact:
        return const EdgeInsets.all(10.0);
      case DisplayDensityMode.ultraCompact:
        return const EdgeInsets.all(8.0);
    }
  }

  const DisplayDensityMode({
    required this.nameAr,
    required this.nameEn,
    required this.rowHeight,
    required this.headerHeight,
    required this.fontSizeDelta,
    required this.buttonHeight,
    required this.buttonPadding,
    required this.buttonFontSize,
    required this.buttonIconSize,
    required this.headerPadding,
    required this.headerTitleFontSize,
    required this.headerSubtitleFontSize,
    required this.headerIconSize,
    required this.toolbarHeight,
    required this.inputFontSize,
    required this.metricCardHeight,
    required this.metricCardPadding,
    required this.metricTitleFontSize,
    required this.metricValueFontSize,
    required this.metricIconSize,
    required this.tableHeaderFontSize,
    required this.tableCellPrimaryFontSize,
    required this.tableCellSecondaryFontSize,
    required this.sidebarNavFontSize,
    required this.topBarHeight,
    required this.tabBarHeight,
    required this.tableRowHeight,
    required this.tableHeadingHeight,
    required this.contentPadding,
  });
}

final displayDensityProvider =
    StateNotifierProvider<DisplayDensityNotifier, DisplayDensityMode>(
        (ref) => DisplayDensityNotifier());

class DisplayDensityNotifier extends StateNotifier<DisplayDensityMode> {
  static const _storageKey = 'importflow_display_density';
  static const _storage = FlutterSecureStorage();

  DisplayDensityNotifier() : super(DisplayDensityMode.comfortable) {
    _loadSavedDensity();
  }

  Future<void> _loadSavedDensity() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'compact') {
        state = DisplayDensityMode.compact;
      } else if (saved == 'ultraCompact') {
        state = DisplayDensityMode.ultraCompact;
      } else {
        state = DisplayDensityMode.comfortable;
      }
    } catch (_) {}
  }

  Future<void> setDensity(DisplayDensityMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _storageKey, value: mode.name);
    } catch (_) {}
  }
}
