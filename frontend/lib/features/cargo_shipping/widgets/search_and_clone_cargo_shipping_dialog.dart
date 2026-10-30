import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/cargo_shipping_model.dart';
import 'cargo_shipping_ui.dart';

/// Search and Clone Previous Cargo Shipping Record Dialog (Screen 26 / UX-CLONE-026)
///
/// Allows operators to quickly search past cargo shipping allocations by code, import file,
/// container number, seal number, or importer, and select one to clone into a new editable draft.
class SearchAndCloneCargoShippingDialog extends StatefulWidget {
  final List<CargoShippingModel> records;
  final ValueChanged<CargoShippingModel> onSelectRecord;

  const SearchAndCloneCargoShippingDialog({
    super.key,
    required this.records,
    required this.onSelectRecord,
  });

  @override
  State<SearchAndCloneCargoShippingDialog> createState() =>
      _SearchAndCloneCargoShippingDialogState();
}

class _SearchAndCloneCargoShippingDialogState
    extends State<SearchAndCloneCargoShippingDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'All';
  String _selectedStatus = 'All';
  late List<CargoShippingModel> _filtered;

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

        final matchesType = _selectedType == 'All' || r.shipmentType == _selectedType;
        if (!matchesType) return false;

        final matchesStatus = _selectedStatus == 'All' || r.status == _selectedStatus;
        if (!matchesStatus) return false;

        if (q.isEmpty) return true;

        final code = r.cargoShippingCode.toLowerCase();
        final file = (r.importFileCode ?? '').toLowerCase();
        final comp = (r.companyName ?? '').toLowerCase();
        final containers = r.containersLoadingData.any(
          (c) => c.containerNo.toLowerCase().contains(q) || c.sealNo.toLowerCase().contains(q),
        );

        return code.contains(q) || file.contains(q) || comp.contains(q) || containers;
      }).toList();
    });
  }

  String _statusLabel(AppLocalizations l, String s) {
    switch (s) {
      case 'All':
        return l.cshAll;
      case 'Completed':
        return l.cargoShippingStatusCompleted;
      case 'Cargo Ready':
        return l.cargoShippingStatusCargoReady;
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: ShippingDialogFrame(
        title: l.cloneCargoShippingDialogTitle,
      subtitle: l.cloneCargoShippingDialogSubtitle,
      icon: Icons.copy_all_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilter(),
            decoration: InputDecoration(
              hintText: l.cshCloneSearchHint,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.cshCloneTypeLabel, style: _labelStyle(context)),
              for (final t in const ['All', 'FCL', 'LCL'])
                ChoiceChip(
                  label: Text(t == 'All' ? l.cshAll : t),
                  selected: _selectedType == t,
                  onSelected: (_) {
                    _selectedType = t;
                    _applyFilter();
                  },
                ),
              const SizedBox(width: 12),
              Text(l.cshCloneStatusLabel, style: _labelStyle(context)),
              for (final s in const ['All', 'Completed', 'Cargo Ready'])
                ChoiceChip(
                  label: Text(_statusLabel(l, s)),
                  selected: _selectedStatus == s,
                  onSelected: (_) {
                    _selectedStatus = s;
                    _applyFilter();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? CcStateView.empty(message: l.cshCloneNoMatches, icon: Icons.search_off_rounded)
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
                    itemBuilder: (context, index) => _row(context, l, _filtered[index]),
                  ),
          ),
        ],
      ),
    ),
    );
  }

  TextStyle _labelStyle(BuildContext context) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context));

  Widget _row(BuildContext context, AppLocalizations l, CargoShippingModel rec) {
    final containerSummary = rec.containersLoadingData.map((c) => '${c.containerNo} (${c.containerType})').join(', ');
    void select() {
      Navigator.of(context).pop();
      widget.onSelectRecord(rec);
    }

    return InkWell(
      onTap: select,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.cobalt.withValues(alpha: 0.12),
              child: const Icon(Icons.local_shipping_outlined, color: AppTheme.cobalt, size: 20),
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
                      Text(
                        rec.cargoShippingCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      CcStatusChip(
                        label: rec.shipmentType,
                        severity: rec.shipmentType == 'FCL' ? AppSeverity.info : AppSeverity.warning,
                      ),
                      CcStatusChip(
                        label: _statusLabel(l, rec.status),
                        severity: ShippingFormat.statusSeverity(rec.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.cshCloneFileLine(rec.importFileCode ?? 'IMP-${rec.importFileId}', rec.companyName ?? ''),
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                  if (containerSummary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l.cshCloneContainersLine(containerSummary),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMutedOf(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              key: Key('selectRecordToCloneBtn_${rec.cargoShippingCode}'),
              label: l.cshCloneBtn,
              icon: Icons.copy_rounded,
              size: AppButtonSize.small,
              onPressed: select,
            ),
          ],
        ),
      ),
    );
  }
}
