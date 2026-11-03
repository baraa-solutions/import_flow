import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_consultation_model.dart';

class AddChecklistItemDialog extends StatefulWidget {
  final Function(CustomsChecklistItemModel) onItemAdded;

  const AddChecklistItemDialog({
    super.key,
    required this.onItemAdded,
  });

  @override
  State<AddChecklistItemDialog> createState() => _AddChecklistItemDialogState();
}

class _AddChecklistItemDialogState extends State<AddChecklistItemDialog> {
  final _docController = TextEditingController();
  final _hsController = TextEditingController();
  final _agencyController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _isRequired = true;
  bool _isBlocking = true;
  String _responsibleParty = 'Customs Broker';
  String _itemStatus = 'Pending';

  @override
  void dispose() {
    _docController.dispose();
    _hsController.dispose();
    _agencyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SelectionArea(
      child: AlertDialog(
        title: Text(
          l.addNewChecklistItem,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _docController,
                  decoration: InputDecoration(
                    labelText: l.itemDescriptionAndOriginCol,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hsController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.customsTariffItemCol,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _responsibleParty,
                  labelText: l.responsiblePartyLabel,
                  items: [
                    SearchableDropdownItem(
                      value: 'Customs Broker',
                      label: l.responsibleCustomsBroker,
                    ),
                    SearchableDropdownItem(
                      value: 'Supplier / Exporter',
                      label: l.responsibleSupplierExporter,
                    ),
                    SearchableDropdownItem(
                      value: 'Importer Team',
                      label: l.responsibleImporterTeam,
                    ),
                    SearchableDropdownItem(
                      value: 'Freight Forwarder',
                      label: l.responsibleFreightForwarder,
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _responsibleParty = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _agencyController,
                  decoration: InputDecoration(
                    labelText: l.regulatoryRequirementsCol,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SearchableDropdownField<String>(
                  value: _itemStatus,
                  labelText: l.statusCol,
                  items: [
                    SearchableDropdownItem(
                      value: 'Pending',
                      label: l.statusPending,
                    ),
                    SearchableDropdownItem(
                      value: 'Received',
                      label: l.statusReceived,
                    ),
                    SearchableDropdownItem(
                      value: 'Verified',
                      label: l.statusVerified,
                    ),
                    SearchableDropdownItem(
                      value: 'Approved',
                      label: l.statusApproved,
                    ),
                    SearchableDropdownItem(
                      value: 'Rejected',
                      label: l.statusRejected,
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _itemStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _isRequired,
                      onChanged: (v) => setState(() => _isRequired = v ?? true),
                    ),
                    Text(l.requiredDocCheckbox),
                    const Spacer(),
                    Checkbox(
                      value: _isBlocking,
                      onChanged: (v) => setState(() => _isBlocking = v ?? true),
                    ),
                    Text(l.blockingShipmentCheckbox),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remarksController,
                  decoration: InputDecoration(
                    labelText: l.notes,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cancel,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: l.save,
            variant: AppButtonVariant.primary,
            onPressed: () {
              final doc = _docController.text.trim();
              if (doc.isEmpty) return;
              widget.onItemAdded(CustomsChecklistItemModel(
                documentType: doc,
                hsCode: _hsController.text.trim().isNotEmpty
                    ? _hsController.text.trim()
                    : null,
                isRequired: _isRequired,
                isBlockingShipment: _isBlocking,
                responsibleParty: _responsibleParty,
                status: _itemStatus,
                regulatoryAgency: _agencyController.text.trim().isNotEmpty
                    ? _agencyController.text.trim()
                    : null,
                remarks: _remarksController.text.trim().isNotEmpty
                    ? _remarksController.text.trim()
                    : null,
              ));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
