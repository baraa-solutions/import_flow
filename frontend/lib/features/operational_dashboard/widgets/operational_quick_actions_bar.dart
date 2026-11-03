import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/directional_icon.dart';
import '../../../../core/widgets/universal_entity_extractor_dialog.dart';

/// Single interactive action button inside the operational quick shortcuts bar.
class OperationalQuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const OperationalQuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            DirectionalIcon(Icons.arrow_forward_ios, size: 10, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Standalone Quick Actions & Shortcuts Bar with AI Smart Extractor.
class OperationalQuickActionsBar extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  final ValueChanged<EntityTarget>? onExtractEntity;

  const OperationalQuickActionsBar({
    super.key,
    this.onNavigate,
    this.onExtractEntity,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Smart Extractor Header & Launch Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.amber.shade700.withValues(alpha: 0.5) : Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.aiSmartExtractorTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal, foregroundColor: Colors.white),
                        icon: const Icon(Icons.public, size: 16),
                        label: Text(l.smartExtractSupplier),
                        onPressed: () {
                          if (onExtractEntity != null) {
                            onExtractEntity!(EntityTarget.supplier);
                          } else {
                            UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.supplier);
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                        icon: const Icon(Icons.domain, size: 16),
                        label: Text(l.smartExtractCompany),
                        onPressed: () {
                          if (onExtractEntity != null) {
                            onExtractEntity!(EntityTarget.company);
                          } else {
                            UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.company);
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                        icon: const Icon(Icons.handshake, size: 16),
                        label: Text(l.smartExtractPartner),
                        onPressed: () {
                          if (onExtractEntity != null) {
                            onExtractEntity!(EntityTarget.partner);
                          } else {
                            UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.partner);
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                        icon: const Icon(Icons.account_balance, size: 16),
                        label: Text(l.smartExtractBank),
                        onPressed: () {
                          if (onExtractEntity != null) {
                            onExtractEntity!(EntityTarget.bank);
                          } else {
                            UniversalEntityExtractorDialog.show(context, initialTarget: EntityTarget.bank);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(Icons.bolt, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.quickShortcutsTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OperationalQuickActionButton(
                  label: l.createNewProject,
                  icon: Icons.assignment_outlined,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  onTap: () => onNavigate?.call(31), // Projects
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewImportFile,
                  icon: Icons.folder_special_outlined,
                  color: isDark ? Colors.tealAccent : AppTheme.emerald,
                  onTap: () => onNavigate?.call(1), // Import Files
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewImportCompany,
                  icon: Icons.domain_outlined,
                  color: isDark ? Colors.amber.shade400 : AppTheme.orange,
                  onTap: () => onNavigate?.call(32), // Import Companies
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewSupplier,
                  icon: Icons.business_outlined,
                  color: isDark ? Colors.tealAccent.shade200 : AppTheme.charcoal,
                  onTap: () => onNavigate?.call(33), // Foreign Suppliers
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewPartnerBank,
                  icon: Icons.account_balance_outlined,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  onTap: () => onNavigate?.call(34), // Partners & Banks
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewCustomsTariff,
                  icon: Icons.description_outlined,
                  color: isDark ? Colors.orange.shade300 : AppTheme.orange,
                  onTap: () => onNavigate?.call(36), // Customs Tariff
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewLocation,
                  icon: Icons.location_on_outlined,
                  color: isDark ? Colors.tealAccent : AppTheme.emerald,
                  onTap: () => onNavigate?.call(37), // Ports & Locations
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewCurrency,
                  icon: Icons.currency_exchange_outlined,
                  color: isDark ? Colors.purpleAccent.shade100 : AppTheme.charcoal,
                  onTap: () => onNavigate?.call(38), // Currencies
                  isDark: isDark,
                ),
                OperationalQuickActionButton(
                  label: l.createNewExchangeRate,
                  icon: Icons.rate_review_outlined,
                  color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                  onTap: () => onNavigate?.call(38), // Exchange Rates
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
