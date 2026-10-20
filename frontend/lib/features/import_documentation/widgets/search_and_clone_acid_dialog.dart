import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/import_documentation_model.dart';

/// Search and Clone Previous ACID Request Dialog (Screen 11 / UX-CLONE-011)
///
/// Allows users to quickly search previous ACID registration sessions by code,
/// ACID number, importer, exporter, PO, or proforma invoice, and select one to clone.
class SearchAndCloneAcidDialog extends StatefulWidget {
  final List<AcidRegistrationModel> sessions;
  final ValueChanged<AcidRegistrationModel> onSelectSession;

  const SearchAndCloneAcidDialog({
    super.key,
    required this.sessions,
    required this.onSelectSession,
  });

  @override
  State<SearchAndCloneAcidDialog> createState() => _SearchAndCloneAcidDialogState();
}

class _SearchAndCloneAcidDialogState extends State<SearchAndCloneAcidDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<AcidRegistrationModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.sessions;
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
        _filtered = widget.sessions;
      } else {
        _filtered = widget.sessions.where((s) {
          final acidNum = s.acidNumber.toLowerCase();
          final acidCode = s.acidCode.toLowerCase();
          final importer = s.importerName.toLowerCase();
          final exporter = s.exporterName.toLowerCase();
          final file = (s.importFileCode ?? '').toLowerCase();
          final po = (s.poNumber ?? '').toLowerCase();
          final prof = s.proformaInvoiceNo.toLowerCase();
          final pol = s.polName.toLowerCase();
          final pod = s.podName.toLowerCase();
          return acidNum.contains(lower) ||
              acidCode.contains(lower) ||
              importer.contains(lower) ||
              exporter.contains(lower) ||
              file.contains(lower) ||
              po.contains(lower) ||
              prof.contains(lower) ||
              pol.contains(lower) ||
              pod.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750, maxHeight: 620),
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
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_all, color: AppTheme.cobalt, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneAcidDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.acidClonedResetNotice,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Input
              TextField(
                key: const Key('searchAndCloneAcidQueryInput'),
                controller: _queryController,
                autofocus: true,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: l.searchAcidHint,
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
                  fillColor: AppTheme.surfaceAltOf(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Results Count
              Text(
                '${_filtered.length} / ${widget.sessions.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // List of Sessions
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 40, color: AppTheme.textMutedOf(context)),
                            const SizedBox(height: 8),
                            Text(
                              l.noAcidsFound,
                              style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: const Key('searchAndCloneAcidListView'),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = _filtered[index];
                          return InkWell(
                            key: Key('cloneAcidSessionTile_${session.acidId}'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelectSession(session);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceAltOf(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.borderOf(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      session.acidNumber.isNotEmpty ? session.acidNumber : session.acidCode,
                                      style: const TextStyle(
                                        color: AppTheme.cobalt,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${session.importerName} ⟵ ${session.exporterName}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryOf(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${session.importFileCode ?? 'بدون ملف'} | ${session.proformaInvoiceNo} | ${session.polName} → ${session.podName}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondaryOf(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: AppTheme.textMutedOf(context),
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
