import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/transport_location_model.dart';
import '../providers/transport_locations_provider.dart';
import 'transport_location_filter_toolbar.dart';

/// Modal dialog for creating and editing Ports & Transport Locations.
class TransportLocationFormDialog {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    TransportLocationModel? location,
  }) async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final locodeCtrl = TextEditingController(text: location?.unLocode ?? '');
    final nameCtrl = TextEditingController(text: location?.locationName ?? '');
    String selectedType = location?.locationType ?? 'Sea Port';
    final countryCtrl = TextEditingController(text: location?.country ?? '');
    final cityCtrl = TextEditingController(text: location?.city ?? '');
    final notesCtrl = TextEditingController(text: location?.notes ?? '');

    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(location == null
              ? l10n.addLocationDialogTitle
              : l10n.editLocationDialogTitle(location.unLocode)),
          content: SelectionArea(
            child: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: locodeCtrl,
                              enabled: location == null,
                              decoration: InputDecoration(
                                labelText: l10n.unLocodeLabel,
                                hintText: l10n.unLocodeHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, locodeCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              value: selectedType,
                              labelText: l10n.locationTypeLabel,
                              items: [
                                'Sea Port',
                                'Airport',
                                'Dry Port',
                                'Land Border',
                                'ICD',
                                'Rail Terminal'
                              ]
                                  .map((t) => SearchableDropdownItem<String>(
                                      value: t,
                                      label: TransportLocationFilterToolbar.getLocationTypeLabel(t, l10n)))
                                  .toList(),
                              onChanged: (v) => selectedType = v ?? 'Sea Port',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.locationNameLabel,
                          hintText: l10n.locationNameHint,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.locationCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? l10n.requiredField
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: countryCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.countryLabelRequired,
                                hintText: l10n.countryHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, countryCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.cityLabelRequired,
                                hintText: l10n.cityHint,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: l10n.locationCopyFieldTooltip,
                                  onPressed: () => CopyHelper.copy(context, cityCtrl.text),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.requiredField
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.locationNotesLabel,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: l10n.locationCopyFieldTooltip,
                            onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            if (location != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                tooltip: l10n.exportLocationPdfBtn,
                onPressed: () => MasterDataExportService.printOrSaveLocationPdf(location),
              ),
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          if (location == null) {
                            final newModel = TransportLocationModel(
                              unLocode: locodeCtrl.text.trim().toUpperCase(),
                              locationName: nameCtrl.text.trim(),
                              locationType: selectedType,
                              country: countryCtrl.text.trim(),
                              city: cityCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            final ok = await ref
                                .read(transportLocationsProvider.notifier)
                                .createLocation(newModel);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          } else {
                            final updateData = {
                              'location_name': nameCtrl.text.trim(),
                              'location_type': selectedType,
                              'country': countryCtrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            };
                            final ok = await ref
                                .read(transportLocationsProvider.notifier)
                                .updateLocation(
                                    location.locationId!, updateData);
                            if (ok && context.mounted) Navigator.pop(dialogCtx);
                          }
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(location == null
                      ? l10n.createLocationSubmitBtn
                      : l10n.saveChangesSubmitBtn),
            ),
          ],
        ),
      ),
    ).then((_) {
      locodeCtrl.dispose();
      nameCtrl.dispose();
      countryCtrl.dispose();
      cityCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}
