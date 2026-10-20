import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';

/// Search and Clone Previous Customs Consultation Dialog (UX-CLONE-011)
///
/// Allows users to quickly search previous customs consultations by code,
/// title, broker name, or notes, and select one to clone into a new draft.
class SearchAndCloneConsultationDialog extends StatefulWidget {
  final List<CustomsConsultationModel> consultations;
  final ValueChanged<CustomsConsultationModel> onSelectConsultation;

  const SearchAndCloneConsultationDialog({
    super.key,
    required this.consultations,
    required this.onSelectConsultation,
  });

  @override
  State<SearchAndCloneConsultationDialog> createState() => _SearchAndCloneConsultationDialogState();
}

class _SearchAndCloneConsultationDialogState extends State<SearchAndCloneConsultationDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<CustomsConsultationModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.consultations;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = widget.consultations;
      } else {
        _filtered = widget.consultations.where((c) {
          final code = c.consultationCode.toLowerCase();
          final title = c.title.toLowerCase();
          final broker = c.brokerName.toLowerCase();
          final notes = (c.notes ?? '').toLowerCase();
          return code.contains(lower) || title.contains(lower) || broker.contains(lower) || notes.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = context.l10n.financialSettlementCurrencyEgp;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneConsultationDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndCloneConsultationSubtitle,
                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
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
              const Divider(height: 24),

              // Search Box
              TextField(
                controller: _queryController,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l.searchByConsultationCodeOrTitleHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cobalt, width: 1.5)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // List of Consultations
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              l.noMatchingConsultationsFound,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final c = _filtered[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => widget.onSelectConsultation(c),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.consultationCode,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (c.brokerName.isNotEmpty)
                                          Text(
                                            '${l.customsBrokerLabel}: ${c.brokerName}',
                                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (c.estimatedDutiesEgp > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${c.estimatedDutiesEgp.toStringAsFixed(0)} $egpLabel',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right, // mirrored by Icon itself in RTL
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
