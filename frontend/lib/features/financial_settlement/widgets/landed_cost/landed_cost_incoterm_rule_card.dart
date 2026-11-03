import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../settlement_ui.dart';

class LandedCostIncotermRuleCard extends StatelessWidget {
  final String incoterm;

  const LandedCostIncotermRuleCard({
    super.key,
    required this.incoterm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inco = incoterm.toUpperCase();

    String ruleTitle;
    String ruleDesc;
    String exporterCovers;
    String importerCovers;

    switch (inco) {
      case 'CIF':
      case 'CIP':
        ruleTitle = l10n.incoCifRuleTitle;
        ruleDesc = l10n.incoCifRuleDesc;
        exporterCovers = l10n.incoCifExporterCovers;
        importerCovers = l10n.incoCifImporterCovers;
        break;
      case 'CFR':
      case 'CPT':
        ruleTitle = l10n.incoCfrRuleTitle;
        ruleDesc = l10n.incoCfrRuleDesc;
        exporterCovers = l10n.incoCfrExporterCovers;
        importerCovers = l10n.incoCfrImporterCovers;
        break;
      case 'EXW':
        ruleTitle = l10n.incoExwRuleTitle;
        ruleDesc = l10n.incoExwRuleDesc;
        exporterCovers = l10n.incoExwExporterCovers;
        importerCovers = l10n.incoExwImporterCovers;
        break;
      case 'DDP':
        ruleTitle = l10n.incoDdpRuleTitle;
        ruleDesc = l10n.incoDdpRuleDesc;
        exporterCovers = l10n.incoDdpExporterCovers;
        importerCovers = l10n.incoDdpImporterCovers;
        break;
      case 'FOB':
      case 'FCA':
      case 'FAS':
      default:
        ruleTitle = l10n.incoFobRuleTitle;
        ruleDesc = l10n.incoFobRuleDesc;
        exporterCovers = l10n.incoFobExporterCovers;
        importerCovers = l10n.incoFobImporterCovers;
        break;
    }

    Widget coverBox(String label, String text, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.charcoal)),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => CopyHelper.copy(context, inco, customMessage: l10n.settlementCmpCopiedIncoterm(inco)),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LtrText(
                        inco,
                        style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy, size: 12, color: AppTheme.white.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ruleTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ruleDesc,
            style: const TextStyle(fontSize: 12, color: AppTheme.textStrong, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              coverBox(l10n.incoRuleExporterCoversLabel, exporterCovers, AppTheme.wcagEmerald),
              const SizedBox(width: 12),
              coverBox(l10n.incoRuleImporterCoversLabel, importerCovers, AppTheme.cobalt),
            ],
          ),
        ],
      ),
    );
  }
}
