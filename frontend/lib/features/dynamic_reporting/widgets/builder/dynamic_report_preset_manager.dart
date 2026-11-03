import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';

/// Manages persistence of custom dynamic report builder presets.
class DynamicReportPresetManager {
  DynamicReportPresetManager._();

  static const String _storageKey = 'importflow_dynamic_report_custom_columns_v2';

  /// Loads persisted column visibility settings from local preferences.
  static Future<void> loadCustomPreset(List<DynamicReportColumn> masterColumns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> savedIds = jsonDecode(raw);
      final savedSet = savedIds.map((e) => e.toString()).toSet();

      for (final col in masterColumns) {
        col.isVisible = savedSet.contains(col.id);
      }
    } catch (_) {
      // Graceful fallback to default configuration if parsing fails.
    }
  }

  /// Saves current column visibility selection into local preferences.
  static Future<void> saveCustomPreset({
    required BuildContext context,
    required List<DynamicReportColumn> masterColumns,
  }) async {
    final l = context.l10n;
    final activeIds = masterColumns
        .where((c) => c.isVisible)
        .map((c) => c.id)
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(activeIds));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.dynPresetSavedToast,
          severity: AppSeverity.success,
        ),
      );
    }
  }

  /// Resets master columns visibility to factory default settings.
  static Future<void> resetToDefault({
    required BuildContext context,
    required List<DynamicReportColumn> masterColumns,
  }) async {
    final l = context.l10n;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    // Default visible IDs
    final defaultVisible = {
      'importFileCode',
      'customFileNumber',
      'companyName',
      'supplierName',
      'brokerName',
      'projectNames',
      'status',
      'currentStage',
      'progressPercent',
      'piValue',
      'incotermCode',
      'shipmentMode',
      'requiredEta',
      'acidNumber',
      'form4No',
    };

    for (final col in masterColumns) {
      col.isVisible = defaultVisible.contains(col.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.dynPresetResetToast,
          severity: AppSeverity.info,
        ),
      );
    }
  }
}
