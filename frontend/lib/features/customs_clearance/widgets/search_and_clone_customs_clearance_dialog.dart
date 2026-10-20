import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../models/customs_clearance_model.dart';
import 'customs_ui.dart';

/// Search and Clone Previous Customs Clearance Record Dialog (Screen 27 / SubTab 0)
///
/// Allows operators to quickly search past customs clearance records by clearance code,
/// Declaration 46 number, D/O number, customs office, or channel, and select one to clone
/// into a new editable draft.
class SearchAndCloneCustomsClearanceDialog extends StatefulWidget {
  final List<CustomsClearanceModel> records;
  final ValueChanged<CustomsClearanceModel> onSelectRecord;

  const SearchAndCloneCustomsClearanceDialog({
    super.key,
    required this.records,
    required this.onSelectRecord,
  });

  @override
  State<SearchAndCloneCustomsClearanceDialog> createState() =>
      _SearchAndCloneCustomsClearanceDialogState();
}

class _SearchAndCloneCustomsClearanceDialogState
    extends State<SearchAndCloneCustomsClearanceDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedChannel = 'All';
  String _selectedStatus = 'All';
  late List<CustomsClearanceModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.records.where((r) => r.isActive).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.records.where((r) {
        if (!r.isActive) return false;

        final matchesChannel = _selectedChannel == 'All' ||
            r.channelType.toLowerCase().contains(_selectedChannel.toLowerCase());
        if (!matchesChannel) return false;

        final matchesStatus =
            _selectedStatus == 'All' || r.status == _selectedStatus;
        if (!matchesStatus) return false;

        if (q.isEmpty) return true;

        final code = r.clearanceCode.toLowerCase();
        final decl = (r.declaration46No ?? '').toLowerCase();
        final don = (r.deliveryOrderNumber ?? '').toLowerCase();
        final office = r.customsOfficeName.toLowerCase();
        final file = 'imp-${r.importFileId}';

        return code.contains(q) ||
            decl.contains(q) ||
            don.contains(q) ||
            office.contains(q) ||
            file.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 920.0);

    final channelLabels = <String, String>{
      'All': l.ccCloneAll,
      'Red': l.ccCloneRed,
      'Green': l.ccCloneGreen,
      'Yellow': l.ccCloneYellow,
    };
    final statusLabels = <String, String>{
      'All': l.customsClearanceFilterAll,
      'Inspection In Progress': l.customsClearanceFilterInspection,
      'Duty Requested': l.customsClearanceFilterDutyRequested,
      'Duty Paid': l.customsClearanceFilterDutyPaid,
      'Final Release Granted': l.customsClearanceFilterFinalRelease,
    };
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: AppTheme.textSecondaryOf(context),
    );

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobaltLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.cloneCustomsClearanceDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.cloneCustomsClearanceDialogSubtitle,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: l.close,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Search Field
              TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilter(),
                decoration: InputDecoration(
                  hintText: l.ccCloneSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceAltOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(l.ccCloneChannelLabel, style: labelStyle),
                    ...channelLabels.entries.map((c) => Padding(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(c.value),
                            selected: _selectedChannel == c.key,
                            onSelected: (_) {
                              setState(() => _selectedChannel = c.key);
                              _applyFilter();
                            },
                          ),
                        )),
                    const SizedBox(width: 12),
                    Text(l.ccCloneStatusLabel, style: labelStyle),
                    ...statusLabels.entries.map((s) => Padding(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(s.value),
                            selected: _selectedStatus == s.key,
                            onSelected: (_) {
                              setState(() => _selectedStatus = s.key);
                              _applyFilter();
                            },
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Records List
              Expanded(
                child: _filtered.isEmpty
                    ? CcStateView.empty(message: l.customsClearanceEmptyRecords, icon: Icons.search_off_rounded)
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildRecordTile(l, _filtered[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildRecordTile(AppLocalizations l, CustomsClearanceModel rec) {
    final channel = CcUi.channelStyle(l, rec.channelType);
    final channelColor = AppTheme.severityForegroundOf(context, channel.severity);
    final duty = rec.effectiveDutyTotal;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(8),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, channel.severity),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(channel.icon, color: channelColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      LtrText(
                        rec.clearanceCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      CcStatusChip(label: channel.label, severity: channel.severity),
                      if (rec.declaration46No != null && rec.declaration46No!.isNotEmpty)
                        LtrText(
                          '46: ${rec.declaration46No}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.cobalt,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rec.customsOfficeName} | ${l.ccCloneDuties}: ${CcFormat.money(duty)} ${l.ccCurrencyShort} | ${rec.status}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              key: Key('selectRecordToCloneBtn_${rec.clearanceCode}'),
              label: l.ccCloneBtn,
              icon: Icons.copy_rounded,
              size: AppButtonSize.small,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSelectRecord(rec);
              },
            ),
          ],
        ),
      ),
    );
  }
}
