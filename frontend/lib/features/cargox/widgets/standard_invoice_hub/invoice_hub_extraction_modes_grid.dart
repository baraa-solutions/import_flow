import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// 4-mode option selector grid for CargoX Multi-Mode extraction.
class InvoiceHubExtractionModesGrid extends StatelessWidget {
  final String selectedMode;
  final void Function(String mode, String grouping) onSelectMode;

  const InvoiceHubExtractionModesGrid({
    super.key,
    required this.selectedMode,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModeOptionCard(
                title: l10n.cargoxModeConsolidatedTitle,
                subtitle: l10n.cargoxModeConsolidatedSubtitle,
                icon: Icons.compress,
                color: AppTheme.emerald,
                isSelected: selectedMode == 'all_consolidated',
                onTap: () => onSelectMode('all_consolidated', 'by_hs_code'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeOptionCard(
                title: l10n.cargoxModeDetailedTitle,
                subtitle: l10n.cargoxModeDetailedSubtitle,
                icon: Icons.list_alt,
                color: AppTheme.cobalt,
                isSelected: selectedMode == 'all_detailed',
                onTap: () => onSelectMode('all_detailed', 'flat'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeOptionCard(
                title: l10n.cargoxModePerInvoiceConsolidatedTitle,
                subtitle: l10n.cargoxModePerInvoiceConsolidatedSubtitle,
                icon: Icons.folder_zip_outlined,
                color: AppTheme.orange,
                isSelected: selectedMode == 'per_invoice_consolidated',
                onTap: () => onSelectMode('per_invoice_consolidated', 'by_hs_code'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeOptionCard(
                title: l10n.cargoxModePerInvoiceDetailedTitle,
                subtitle: l10n.cargoxModePerInvoiceDetailedSubtitle,
                icon: Icons.inventory_2_outlined,
                color: Colors.purple,
                isSelected: selectedMode == 'per_invoice_detailed',
                onTap: () => onSelectMode('per_invoice_detailed', 'flat'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? color : AppTheme.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
