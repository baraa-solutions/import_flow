import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

/// Toolbar component for Screen 22: Smart Invoice vs B/L Matcher.
///
/// Contains view mode switching (Inspector vs Sessions Registry),
/// Import File linkage selector, active session badge, and carrier/sensitivity controls.
class InvoiceBlMatcherToolbar extends StatelessWidget {
  final int activeViewMode;
  final ValueChanged<int> onViewModeChanged;
  final int sessionCount;
  final List<dynamic> importFiles;
  final int? activeFileId;
  final ValueChanged<int?> onFileSelected;
  final String? activeSessionCode;
  final String? carrierCode;
  final double? sensitivity;
  final ValueChanged<double>? onSensitivityChanged;

  const InvoiceBlMatcherToolbar({
    super.key,
    required this.activeViewMode,
    required this.onViewModeChanged,
    required this.sessionCount,
    required this.importFiles,
    required this.activeFileId,
    required this.onFileSelected,
    this.activeSessionCode,
    this.carrierCode,
    this.sensitivity,
    this.onSensitivityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildViewModeToggle(context),
        if (activeViewMode == 0) ...[
          const SizedBox(height: 16),
          _buildHeaderControlBar(context),
        ],
      ],
    );
  }

  Widget _buildViewModeToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.borderOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('matcherTabToggleBtn'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onViewModeChanged(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: activeViewMode == 0 ? AppTheme.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: activeViewMode == 0
                      ? [
                          BoxShadow(
                            color: AppTheme.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 18,
                      color: activeViewMode == 0 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabInspect,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: activeViewMode == 0 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const Key('sessionsTabToggleBtn'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onViewModeChanged(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: activeViewMode == 1 ? AppTheme.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: activeViewMode == 1
                      ? [
                          BoxShadow(
                            color: AppTheme.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_edu_rounded,
                      size: 18,
                      color: activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.invoiceBlMatchTabHistory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeViewMode == 1 ? AppTheme.cobalt : AppTheme.textMutedOf(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$sessionCount',
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderControlBar(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;

          final titleWidget = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.invoiceBlMatcherTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.invoiceBlMatcherSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (activeSessionCode != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          context.l10n.idocAActiveSessionUnderReview(activeSessionCode!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ],
                    if (carrierCode != null && carrierCode!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_boat_outlined, size: 14, color: AppTheme.emerald),
                          const SizedBox(width: 4),
                          Text(
                            carrierCode!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final fileDropdown = SearchableDropdownField<int>(
            labelText: l.invoiceBlMatcherLinkImportFile,
            hintText: l.invoiceBlMatcherSelectFileHint,
            value: activeFileId,
            items: importFiles
                .map(
                  (f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.supplierName} (${f.status})',
                  ),
                )
                .toList(),
            onChanged: onFileSelected,
          );

          Widget sensitivitySliderWidget() {
            if (sensitivity == null || onSensitivityChanged == null) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${(sensitivity! * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: sensitivity!,
                      min: 0.5,
                      max: 1.0,
                      onChanged: onSensitivityChanged,
                    ),
                  ),
                ),
              ],
            );
          }

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                const SizedBox(height: 12),
                fileDropdown,
                if (sensitivity != null) ...[
                  const SizedBox(height: 8),
                  sensitivitySliderWidget(),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              if (sensitivity != null) ...[
                sensitivitySliderWidget(),
                const SizedBox(width: 12),
              ],
              SizedBox(width: 320, child: fileDropdown),
            ],
          );
        },
      ),
    );
  }
}
