import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';

/// Embedded header for CargoX Hub displaying title and segmented tab switcher.
class CargoXHubEmbeddedHeader extends StatelessWidget {
  final int selectedSubTab;
  final ValueChanged<int> onTabSelected;

  const CargoXHubEmbeddedHeader({
    super.key,
    required this.selectedSubTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, color: AppTheme.cobalt, size: 20),
            const SizedBox(width: 8),
            Text(
              context.l10n.cargoxEmbeddedTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 24),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(
                    context.l10n.cargoxSegStandardInvoice,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(
                    context.l10n.cargoxSegCreateEnvelope,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(
                    context.l10n.cargoxSegTrackingHub,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text(
                    context.l10n.cargoxSegManifestViewer,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              selected: {selectedSubTab},
              onSelectionChanged: (set) => onTabSelected(set.first),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to build header action buttons for VerticalStageScaffold.
class CargoXHubHeaderActions {
  static List<Widget> build(
    BuildContext context, {
    required int? selectedImportFileId,
    required VoidCallback onRefresh,
  }) {
    return [
      AppButton(
        label: context.l10n.cargoxAiDocumentExtractionBtn,
        icon: Icons.auto_awesome,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.small,
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => SmartInvoiceBLExtractorDialog(
              initialImportFileId: selectedImportFileId,
              initialTabIndex: 0,
            ),
          );
        },
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white70),
        tooltip: context.l10n.cargoxLiveRefreshTooltip,
        onPressed: onRefresh,
      ),
    ];
  }
}
