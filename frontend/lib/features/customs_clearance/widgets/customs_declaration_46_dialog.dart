import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/customs_clearance_provider.dart';
import 'cc_dialog_shell.dart';
import 'customs_ui.dart';

/// Modal dialog for CS-03: Customs Declaration 46 Registration
/// (register the customs declaration and form 46).
class CustomsDeclaration46Dialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const CustomsDeclaration46Dialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomsDeclaration46Dialog(file: file),
    );
  }

  @override
  ConsumerState<CustomsDeclaration46Dialog> createState() =>
      _CustomsDeclaration46DialogState();
}

class _CustomsDeclaration46DialogState
    extends ConsumerState<CustomsDeclaration46Dialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _declaration46Controller;
  late TextEditingController _mtsCertController;
  late TextEditingController _tariffCountController;
  late TextEditingController _inspectionNotesController;

  DateTime _declarationDate = DateTime.now();
  String _selectedOffice = 'Alexandria Port Customs';
  String _selectedChannel = 'Red Channel';
  final Set<String> _selectedRegulatoryBodies = {'GOEIC'};

  bool _isSubmitting = false;

  final List<String> _customsOffices = [
    'Alexandria Port Customs',
    'El Dekheila Port Customs',
    'Port Said Customs',
    'Damietta Port Customs',
    'Sokhna Port Customs',
    'Cairo Airport Cargo Customs',
    '6th of October Dry Port Customs',
    '10th of Ramadan Dry Port Customs',
    'Adabiya Port Customs',
  ];

  final List<String> _regulatoryAgencyOptions = const [
    'GOEIC',
    'NFSA',
    'NTRA',
    'CHEMISTRY_DEPT',
    'QUARANTINE',
    'EDA',
    'INDUSTRIAL_CONTROL',
  ];

  String _officeLabel(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.ccDecOffice0;
      case 1:
        return l.ccDecOffice1;
      case 2:
        return l.ccDecOffice2;
      case 3:
        return l.ccDecOffice3;
      case 4:
        return l.ccDecOffice4;
      case 5:
        return l.ccDecOffice5;
      case 6:
        return l.ccDecOffice6;
      case 7:
        return l.ccDecOffice7;
      default:
        return l.ccDecOffice8;
    }
  }

  @override
  void initState() {
    super.initState();
    _declaration46Controller = TextEditingController(
      text: widget.file.form46No ?? '',
    );
    _mtsCertController = TextEditingController();
    _tariffCountController = TextEditingController(text: '1');
    _inspectionNotesController = TextEditingController();

    if (_declaration46Controller.text.trim().isEmpty) {
      _generateDeclaration46Number();
    }

    if (widget.file.portOfDischarge != null &&
        widget.file.portOfDischarge!.isNotEmpty) {
      final pod = widget.file.portOfDischarge!.toLowerCase();
      if (pod.contains('dekheila') || pod.contains('دخيلة')) {
        _selectedOffice = 'El Dekheila Port Customs';
      } else if (pod.contains('alex') || pod.contains('إسكندرية')) {
        _selectedOffice = 'Alexandria Port Customs';
      } else if (pod.contains('said') || pod.contains('بورسعيد')) {
        _selectedOffice = 'Port Said Customs';
      } else if (pod.contains('damietta') || pod.contains('دمياط')) {
        _selectedOffice = 'Damietta Port Customs';
      } else if (pod.contains('sokhna') || pod.contains('سخنة')) {
        _selectedOffice = 'Sokhna Port Customs';
      }
    }
  }

  @override
  void dispose() {
    _declaration46Controller.dispose();
    _mtsCertController.dispose();
    _tariffCountController.dispose();
    _inspectionNotesController.dispose();
    super.dispose();
  }

  void _generateDeclaration46Number() {
    final year = DateTime.now().year;
    final rand = 10000 + Random().nextInt(90000);
    String portPrefix = 'ALX';
    if (_selectedOffice.contains('Dekheila')) {
      portPrefix = 'DKH';
    } else if (_selectedOffice.contains('Port Said')) {
      portPrefix = 'PSD';
    } else if (_selectedOffice.contains('Damietta')) {
      portPrefix = 'DMT';
    } else if (_selectedOffice.contains('Sokhna')) {
      portPrefix = 'SKH';
    } else if (_selectedOffice.contains('Airport')) {
      portPrefix = 'CAI';
    }

    setState(() {
      _declaration46Controller.text = '46-$year-$portPrefix-$rand';
      if (_mtsCertController.text.trim().isEmpty) {
        _mtsCertController.text = 'MTS-$year-$portPrefix-${rand + 100}';
      }
    });
  }

  Future<void> _selectDeclarationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _declarationDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _declarationDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);

    try {
      final itemsCount = int.tryParse(_tariffCountController.text.trim()) ?? 1;

      final payload = {
        'import_file_id': widget.file.importFileId,
        'declaration_46_no': _declaration46Controller.text.trim(),
        'declaration_46_date': _declarationDate.toIso8601String(),
        'customs_office_name': _selectedOffice,
        'channel_type': _selectedChannel,
        'regulatory_bodies': _selectedRegulatoryBodies.toList(),
        'mts_certificate_number': _mtsCertController.text.trim().isNotEmpty
            ? _mtsCertController.text.trim()
            : null,
        'customs_tariff_items_count': itemsCount,
        'inspection_notes': _inspectionNotesController.text.trim().isNotEmpty
            ? _inspectionNotesController.text.trim()
            : null,
      };
      final number = _declaration46Controller.text.trim();
      final channel = _selectedChannel;

      await ref
          .read(customsClearanceProvider.notifier)
          .registerDeclaration46(payload);

      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.ccDecSuccess(number, channel), severity: AppSeverity.success),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccDecError(ApiErrorText.of(l, e)),
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _isDirty {
    if (_declaration46Controller.text.trim() != (widget.file.form46No ?? '')) return true;
    if (_mtsCertController.text.trim().isNotEmpty) return true;
    if (_inspectionNotesController.text.trim().isNotEmpty) return true;
    if (_selectedChannel != 'Red Channel') return true;
    return false;
  }

  InputDecoration _dec(String label, {IconData? icon, String? helper, String? hint}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        helperText: helper,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: CcStageDialogShell(
        title: l.ccDecTitle,
        icon: Icons.description_rounded,
        accent: AppTheme.orange,
        maxWidth: 860,
        confirmKey: const Key('submitDeclaration46Btn'),
        closeKey: const Key('cancelDeclaration46Btn'),
        confirmLabel: l.ccDecConfirm,
        loadingLabel: l.ccDecConfirming,
        confirmIcon: Icons.check_circle_rounded,
        confirmVariant: AppButtonVariant.warning,
        isSubmitting: _isSubmitting,
        onConfirm: _handleSubmit,
        onCancel: () => UnsavedChangesGuard.maybePop(context, isDirty: _isDirty),
        footerLeading: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: AppTheme.textMutedOf(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.ccDecFooterNote,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.ccDecSubtitle,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
              const SizedBox(height: 12),
              _buildShipmentSummaryBanner(l),
              const SizedBox(height: 20),

              CcFormSection(
                title: l.ccDecSection1,
                icon: Icons.receipt_long_rounded,
                accent: AppTheme.orange,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: const Key('declaration46NoField'),
                        controller: _declaration46Controller,
                        textDirection: TextDirection.ltr,
                        decoration: _dec(l.ccDecNoLabel, icon: Icons.pin_rounded, helper: l.ccDecNoHelper),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l.ccDecNoRequired;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 4),
                      child: AppButton(
                        key: const Key('generateDeclaration46Btn'),
                        label: l.ccDecGenerate,
                        icon: Icons.autorenew_rounded,
                        variant: AppButtonVariant.secondary,
                        tooltip: l.ccDecGenerateTooltip,
                        onPressed: _generateDeclaration46Number,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selectDeclarationDate,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: InputDecorator(
                          decoration: _dec(l.ccDecDateLabel, icon: Icons.calendar_month_rounded),
                          child: LtrText(CcFormat.date(_declarationDate),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CcFormSection(
                title: l.ccDecSection2,
                icon: Icons.account_balance_rounded,
                accent: AppTheme.orange,
                child: SearchableDropdownField<String>(
                  key: const Key('customsOfficeDropdown'),
                  labelText: l.ccDecOfficeLabel,
                  hintText: l.ccDecOfficeHint,
                  items: [
                    for (var i = 0; i < _customsOffices.length; i++)
                      SearchableDropdownItem<String>(
                        value: _customsOffices[i],
                        label: _officeLabel(l, i) == _customsOffices[i]
                            ? _customsOffices[i]
                            : '${_officeLabel(l, i)} (${_customsOffices[i]})',
                      ),
                  ],
                  value: _selectedOffice,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedOffice = val);
                  },
                ),
              ),
              const SizedBox(height: 20),

              CcFormSection(
                title: l.ccDecSection3,
                icon: Icons.alt_route_rounded,
                accent: AppTheme.orange,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.ccDecSection3Desc,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                    ),
                    const SizedBox(height: 10),
                    _buildChannelSelector(l),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CcFormSection(
                title: l.ccDecBodiesSection,
                icon: Icons.policy_rounded,
                accent: AppTheme.orange,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _regulatoryAgencyOptions.map((agency) {
                          final isSelected = _selectedRegulatoryBodies.contains(agency);
                          return FilterChip(
                            selected: isSelected,
                            showCheckmark: true,
                            selectedColor: AppTheme.orangeLight,
                            checkmarkColor: AppTheme.orange,
                            label: Text(
                              DomainEnums.label(l, DomainEnumType.regulatoryBody, agency),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.warningForeground : AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            onSelected: (checked) {
                              setState(() {
                                if (checked) {
                                  _selectedRegulatoryBodies.add(agency);
                                } else {
                                  _selectedRegulatoryBodies.remove(agency);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        key: const Key('tariffCountField'),
                        controller: _tariffCountController,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _dec(l.ccDecTariffLabel, icon: Icons.format_list_numbered_rounded),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1) return l.ccDecTariffMin;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CcFormSection(
                title: l.ccDecSection5,
                icon: Icons.note_alt_rounded,
                accent: AppTheme.orange,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('mtsCertField'),
                      controller: _mtsCertController,
                      textDirection: TextDirection.ltr,
                      decoration: _dec(l.ccDecMtsLabel, icon: Icons.verified_outlined, helper: l.ccDecMtsHelper),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('declarationNotesField'),
                      controller: _inspectionNotesController,
                      maxLines: 2,
                      decoration: _dec(l.ccDecNotesLabel, icon: Icons.chat_bubble_outline_rounded, hint: l.ccDecNotesHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShipmentSummaryBanner(AppLocalizations l) {
    final file = widget.file;
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.emeraldBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(10),
            decoration: const BoxDecoration(color: AppTheme.emeraldLight, shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildBannerItem(l.ccDecBannerFile, file.primaryNameWithCode),
                _buildBannerItem(l.ccDecBannerCompany, file.companyName),
                _buildBannerItem(l.ccDecBannerSupplier, file.supplierName),
                _buildBannerItem(l.ccDecBannerPort, file.portOfDischarge ?? '—'),
                _buildBannerItem(l.ccDecBannerAcid, file.acidNumber ?? '—'),
                _buildBannerItem(l.ccDecBannerDo, file.deliveryOrderNo ?? '—'),
                _buildBannerItem(l.ccDecBannerBroker, file.brokerName ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChannelSelector(AppLocalizations l) {
    final channels = <({String code, String label, String desc, AppSeverity severity, IconData icon})>[
      (
        code: 'Red Channel',
        label: l.ccDecChRed,
        desc: l.ccDecChRedDesc,
        severity: AppSeverity.danger,
        icon: Icons.security_rounded
      ),
      (
        code: 'Yellow Channel',
        label: l.ccDecChYellow,
        desc: l.ccDecChYellowDesc,
        severity: AppSeverity.warning,
        icon: Icons.rule_folder_rounded
      ),
      (
        code: 'Green Channel',
        label: l.ccDecChGreen,
        desc: l.ccDecChGreenDesc,
        severity: AppSeverity.success,
        icon: Icons.verified_user_rounded
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: channels.map((ch) {
        final color = AppTheme.severityForegroundOf(context, ch.severity);
        final isSelected = _selectedChannel == ch.code;

        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedChannel = ch.code),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.severityBackgroundOf(context, ch.severity)
                      : AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.borderOf(context),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ch.icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ch.label,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: color, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ch.desc,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
