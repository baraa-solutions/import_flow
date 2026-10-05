import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Modal dialog for CS-01: Customs Broker Electronic Authorization
/// (assign the customs broker and issue the electronic authorization).
class CustomsBrokerAuthorizationDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const CustomsBrokerAuthorizationDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsBrokerAuthorizationDialog(file: file),
    );
  }

  @override
  ConsumerState<CustomsBrokerAuthorizationDialog> createState() =>
      _CustomsBrokerAuthorizationDialogState();
}

class _CustomsBrokerAuthorizationDialogState
    extends ConsumerState<CustomsBrokerAuthorizationDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedBrokerId;
  late TextEditingController _delegationNoController;
  late TextEditingController _notesController;
  DateTime _delegationDate = DateTime.now();
  String _selectedCustomsOffice = 'Alexandria Port Customs';
  bool _generateMandateLetter = true;
  bool _isSubmitting = false;

  final List<String> _customsOffices = [
    'Alexandria Port Customs',
    'El Dekheila Port Customs',
    'Port Said Port Customs',
    'Ain Sokhna Customs',
    'Damietta Port Customs',
    'Cairo Airport Cargo Customs',
    'Adabiya Port Customs',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBrokerId = widget.file.brokerId;
    _delegationNoController = TextEditingController(
      text: widget.file.customsBrokerDelegationNo ?? '',
    );
    _notesController = TextEditingController();

    if (_delegationNoController.text.trim().isEmpty) {
      _generateDelegationNumber();
    }

    if (widget.file.portOfDischarge != null &&
        widget.file.portOfDischarge!.trim().isNotEmpty) {
      final pod = widget.file.portOfDischarge!.trim();
      final match = _customsOffices.firstWhere(
        (o) => o.toLowerCase().contains(pod.toLowerCase()) || pod.toLowerCase().contains(o.toLowerCase()),
        orElse: () => _customsOffices.first,
      );
      _selectedCustomsOffice = match;
    }

    Future.microtask(() {
      ref.read(allPartnersProvider.notifier).fetchPartners();
    });
  }

  @override
  void dispose() {
    _delegationNoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateDelegationNumber() {
    final year = DateTime.now().year;
    final randNum = 1000 + Random().nextInt(9000);
    String portPrefix = 'ALEX';
    if (_selectedCustomsOffice.contains('Dekheila')) {
      portPrefix = 'DEKH';
    } else if (_selectedCustomsOffice.contains('Port Said')) {
      portPrefix = 'PSD';
    } else if (_selectedCustomsOffice.contains('Sokhna')) {
      portPrefix = 'SOKH';
    } else if (_selectedCustomsOffice.contains('Airport')) {
      portPrefix = 'CAI';
    }
    setState(() {
      _delegationNoController.text = 'DEL-$year-$portPrefix-$randNum';
    });
  }

  Future<void> _submitAuthorization() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrokerId == null) {
      messenger.showSnackBar(
        AppTheme.snackBar(context, l.ccBrkSelectBroker, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'broker_id': _selectedBrokerId,
        'delegation_number': _delegationNoController.text.trim(),
        'delegation_date': _delegationDate.toIso8601String(),
        'customs_office_name': _selectedCustomsOffice,
        'authorization_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'generate_mandate_letter': _generateMandateLetter,
      };
      final number = _delegationNoController.text.trim();
      final successBar = AppTheme.snackBar(context, l.ccBrkSuccess(number), severity: AppSeverity.success);

      await ref.read(customsClearanceProvider.notifier).authorizeBroker(payload);

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(successBar);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccBrkFail(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon, Widget? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixIcon: suffix,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  @override
  Widget build(BuildContext context) {
    final allPartnersAsync = ref.watch(allPartnersProvider);
    final l = context.l10n;
    const infoColor = AppTheme.infoForeground;

    return CcStageDialogShell(
      title: l.ccBrkTitle,
      icon: Icons.assignment_ind_rounded,
      accent: AppTheme.cobalt,
      maxWidth: 720,
      chips: [
        CcHeaderChip(Icons.folder_outlined, widget.file.primaryNameWithCode),
        CcHeaderChip(Icons.business_outlined, l.ccBrkSupplierChip(widget.file.supplierName)),
      ],
      confirmKey: const Key('confirmBrokerAuthorizationBtn'),
      confirmLabel: l.ccBrkConfirm,
      loadingLabel: l.ccBrkConfirming,
      confirmIcon: Icons.verified_rounded,
      confirmVariant: AppButtonVariant.primary,
      isSubmitting: _isSubmitting,
      onConfirm: _submitAuthorization,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.cobaltBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: infoColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.ccBrkInfo,
                      style: const TextStyle(fontSize: 12.5, color: infoColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 1. Customs Broker Selector (SearchableDropdownField)
            allPartnersAsync.when(
              data: (partners) {
                final brokers = partners.where((p) {
                  final cat = p.partnerType.toLowerCase();
                  return cat.contains('broker') ||
                      cat.contains('customs') ||
                      cat.contains('تخليص') ||
                      cat.contains('مخلص');
                }).toList();

                final items = brokers.map((b) {
                  final lic = b.clearanceLicenseNumber != null && b.clearanceLicenseNumber!.isNotEmpty
                      ? '${l.ccBrkLicense} ${b.clearanceLicenseNumber}'
                      : '';
                  final ports = b.authorizedPorts != null && b.authorizedPorts!.isNotEmpty
                      ? ' | ${l.ccBrkPorts} ${b.authorizedPorts}'
                      : '';
                  return SearchableDropdownItem<int>(
                    value: b.providerId ?? 0,
                    label: b.partnerName,
                    subtitle: '$lic$ports'.trim().isEmpty ? null : '$lic$ports'.trim(),
                    icon: Icons.gavel_rounded,
                  );
                }).toList();

                return SearchableDropdownField<int>(
                  key: const Key('customsBrokerDropdownField'),
                  value: _selectedBrokerId,
                  items: items,
                  isRequired: true,
                  labelText: l.ccBrkBrokerLabel,
                  hintText: l.ccBrkBrokerHint,
                  searchHintText: l.ccBrkBrokerSearchHint,
                  onChanged: (val) {
                    setState(() {
                      _selectedBrokerId = val;
                    });
                  },
                  validator: (val) => val == null || val == 0 ? l.ccBrkSelectBroker : null,
                );
              },
              loading: () => const CcStateView.loading(),
              error: (err, _) => Container(
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  l.ccBrkLoadError(ApiErrorText.of(l, err)),
                  style: const TextStyle(color: AppTheme.dangerForeground),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Electronic Delegation Number & Generator
            TextFormField(
              key: const Key('delegationNumberField'),
              controller: _delegationNoController,
              textDirection: TextDirection.ltr,
              decoration: _dec(
                l.ccBrkNoLabel,
                hint: l.ccBrkNoHint,
                icon: Icons.qr_code_rounded,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: l.ccBrkCopyTooltip,
                      onPressed: () {
                        if (_delegationNoController.text.trim().isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: _delegationNoController.text.trim()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(context, l.ccBrkCopied, severity: AppSeverity.success),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.cobalt, size: 20),
                      tooltip: l.ccBrkGenerateTooltip,
                      onPressed: _generateDelegationNumber,
                    ),
                  ],
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return l.ccBrkNoRequired;
                if (val.trim().length < 3) return l.ccBrkNoTooShort;
                return null;
              },
            ),
            const SizedBox(height: 18),

            // 3. Delegation Date & Customs Office
            CcFieldRow(
              gap: 14,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _delegationDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _delegationDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: _dec(l.ccBrkDateLabel, icon: Icons.calendar_month_rounded),
                    child: LtrText(CcFormat.date(_delegationDate), style: const TextStyle(fontSize: 14)),
                  ),
                ),
                SearchableDropdownField<String>(
                  key: const Key('customsOfficeDropdown'),
                  value: _selectedCustomsOffice,
                  isRequired: true,
                  labelText: l.ccBrkOfficeLabel,
                  decoration: _dec(l.ccBrkOfficeLabel, icon: Icons.account_balance_rounded),
                  items: _customsOffices
                      .map((o) => SearchableDropdownItem<String>(value: o, label: o))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCustomsOffice = val);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Checkbox for Formal Mandate Letter
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              // Own Material so the tile's ink is not hidden by the coloured box.
              child: Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  key: const Key('generateMandateLetterCheckbox'),
                  value: _generateMandateLetter,
                  onChanged: (val) {
                    setState(() => _generateMandateLetter = val ?? true);
                  },
                  title: Text(
                    l.ccBrkMandateTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l.ccBrkMandateDesc,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                  activeColor: AppTheme.cobalt,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 5. Notes & Instructions
            TextFormField(
              key: const Key('authorizationNotesField'),
              controller: _notesController,
              maxLines: 2,
              decoration: _dec(l.ccBrkNotesLabel, hint: l.ccBrkNotesHint, icon: Icons.notes_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
