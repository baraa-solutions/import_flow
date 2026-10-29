import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/shipping_scenario_model.dart';

class SearchAndCloneStudyDialog extends StatefulWidget {
  final List<ShippingEvaluationModel> sessions;
  final ValueChanged<ShippingEvaluationModel> onSelectStudy;

  const SearchAndCloneStudyDialog({
    super.key,
    required this.sessions,
    required this.onSelectStudy,
  });

  @override
  State<SearchAndCloneStudyDialog> createState() => _SearchAndCloneStudyDialogState();
}

class _SearchAndCloneStudyDialogState extends State<SearchAndCloneStudyDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<ShippingEvaluationModel> _filteredStudies;

  @override
  void initState() {
    super.initState();
    _filteredStudies = widget.sessions;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudies = widget.sessions;
      } else {
        _filteredStudies = widget.sessions.where((s) {
          final code = s.sessionCode.toLowerCase();
          final title = (s.title ?? '').toLowerCase();
          final imp = (s.importFileCode ?? '').toLowerCase();
          final po = (s.poNumber ?? '').toLowerCase();
          final prj = (s.projectName ?? '').toLowerCase();
          final rec = (s.recommendedScenarioProvider ?? '').toLowerCase();
          return code.contains(query) ||
              title.contains(query) ||
              imp.contains(query) ||
              po.contains(query) ||
              prj.contains(query) ||
              rec.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      child: SelectionArea(
        child: Container(
          width: math.min(720.0, screenWidth - 32),
          height: math.min(600.0, screenHeight - 64),
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.copy_all_rounded, color: AppTheme.cobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.searchAndCloneStudyDialogTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchAndCloneStudySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search input
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.searchByStudyCodeOrTitleHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _queryController.clear(),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),

            // Results list
            Expanded(
              child: _filteredStudies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            l.noMatchingStudiesFound,
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredStudies.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final study = _filteredStudies[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.cobalt.withValues(alpha: 0.15),
                            child: const Icon(Icons.alt_route, color: AppTheme.cobalt, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                study.sessionCode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                              ),
                              if (study.title != null && study.title!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    study.title!,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('${l.crdLabel}: ${study.cargoReadyDate}', style: const TextStyle(fontSize: 11)),
                                Text('• ${study.items.length} ${l.shippingCarrierOptions}', style: const TextStyle(fontSize: 11)),
                                if (study.recommendedScenarioProvider != null)
                                  Text('• 🏆 ${study.recommendedScenarioProvider}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                                if (study.importFileCode != null)
                                  Text('• 📁 ${study.importFileCode}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                          trailing: AppButton(
                            label: l.cloneRowTooltip,
                            icon: Icons.copy_rounded,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () => widget.onSelectStudy(study),
                          ),
                          onTap: () => widget.onSelectStudy(study),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
