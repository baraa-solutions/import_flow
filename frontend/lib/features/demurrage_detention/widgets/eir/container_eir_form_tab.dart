import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../l10n/container_eir_l10n.dart';
import '../../models/container_eir_model.dart';

class ContainerEirFormTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<ContainerLedgerItemModel> containers;
  final int? selectedContainerId;
  final String? selectedContainerNumber;
  final void Function(int id, String number) onContainerChanged;
  final TextEditingController eirNumberCtrl;
  final DateTime emptyReturnDate;
  final ValueChanged<DateTime> onDateChanged;
  final String conditionStatus;
  final ValueChanged<String> onConditionChanged;
  final TextEditingController depotNameCtrl;
  final TextEditingController notesCtrl;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const ContainerEirFormTab({
    super.key,
    required this.formKey,
    required this.containers,
    required this.selectedContainerId,
    required this.selectedContainerNumber,
    required this.onContainerChanged,
    required this.eirNumberCtrl,
    required this.emptyReturnDate,
    required this.onDateChanged,
    required this.conditionStatus,
    required this.onConditionChanged,
    required this.depotNameCtrl,
    required this.notesCtrl,
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.demurrageFreezeNotice,
                      style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Container selection
            if (containers.isNotEmpty) ...[
              InputDecorator(
                decoration: InputDecoration(
                  labelText: l.containerNumberLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedContainerId,
                    isDense: true,
                    isExpanded: true,
                    items: containers.map((c) {
                      final badgeText = c.isDemurrageStopped ? ' (${l.statusReturnedStopped})' : '';
                      return DropdownMenuItem<int>(
                        value: c.containerId,
                        child: Text('${c.containerNumber} [${c.containerType}]$badgeText'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final matched = containers.firstWhere((e) => e.containerId == val);
                        onContainerChanged(val, matched.containerNumber);
                      }
                    },
                  ),
                ),
              ),
            ] else ...[
              CustomTextField(
                controller: TextEditingController(text: selectedContainerNumber ?? ''),
                label: l.containerNumberLabel,
                hint: l.containerNumberHint,
                enabled: false,
                textDirection: TextDirection.ltr,
              ),
            ],
            const SizedBox(height: 16),

            // EIR Number + Copy Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: eirNumberCtrl,
                    label: l.eirNumberLabel,
                    hint: l.eirNumberHint,
                    isRequired: true,
                    textDirection: TextDirection.ltr,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l.requiredEirNumber;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l.copyEirNumber,
                    onPressed: () => CopyHelper.copy(context, eirNumberCtrl.text.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date picker & Condition
            Row(
              children: [
                Expanded(
                  child: AppDatePickerField(
                    label: l.returnDateLabel,
                    value: emptyReturnDate,
                    isRequired: true,
                    onChanged: (d) {
                      if (d != null) onDateChanged(d);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l.inspectionConditionLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: conditionStatus,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'Sound and Clean', child: Text(l.conditionSoundClean)),
                          DropdownMenuItem(value: 'Damaged', child: Text(l.conditionDamaged)),
                          DropdownMenuItem(value: 'Requires Cleaning', child: Text(l.conditionRequiresCleaning)),
                        ],
                        onChanged: (val) {
                          if (val != null) onConditionChanged(val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Depot name
            CustomTextField(
              controller: depotNameCtrl,
              label: l.depotNameLabel,
              hint: l.depotNameHint,
            ),
            const SizedBox(height: 16),

            // Additional Notes
            CustomTextField(
              controller: notesCtrl,
              label: l.notesLabel,
              hint: l.notesHint,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: l.cancelBtn,
                  variant: AppButtonVariant.secondary,
                  onPressed: onCancel,
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: l.confirmEirBtn,
                  variant: AppButtonVariant.success,
                  icon: Icons.check_circle_outline,
                  isLoading: isSubmitting,
                  onPressed: onSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
