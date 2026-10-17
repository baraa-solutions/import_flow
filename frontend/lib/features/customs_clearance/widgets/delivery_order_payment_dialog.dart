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

/// Modal dialog for CS-02: Delivery Order (D/O) Payment & Receipt
/// (pay the shipping agency fees and receive the delivery order).
class DeliveryOrderPaymentDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const DeliveryOrderPaymentDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeliveryOrderPaymentDialog(file: file),
    );
  }

  @override
  ConsumerState<DeliveryOrderPaymentDialog> createState() =>
      _DeliveryOrderPaymentDialogState();
}

class _DeliveryOrderPaymentDialogState
    extends ConsumerState<DeliveryOrderPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedShippingAgentId;
  String? _selectedShippingAgentName;
  late TextEditingController _doNumberController;
  late TextEditingController _feesController;
  late TextEditingController _paymentRefController;
  late TextEditingController _fileUrlController;
  late TextEditingController _notesController;
  late TextEditingController _freeDaysController;

  DateTime _doDate = DateTime.now();
  DateTime? _doExpiryDate;
  int? _freeDaysAllowed;
  String _selectedCurrency = 'EGP';
  bool _isSubmitting = false;

  final List<String> _currencies = ['EGP', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    if (widget.file.deliveryOrderDate != null && widget.file.deliveryOrderDate!.isNotEmpty) {
      final parsedDate = DateTime.tryParse(widget.file.deliveryOrderDate!);
      if (parsedDate != null) _doDate = parsedDate;
    }

    if (widget.file.deliveryOrderExpiryDate != null && widget.file.deliveryOrderExpiryDate!.isNotEmpty) {
      final parsedExpiry = DateTime.tryParse(widget.file.deliveryOrderExpiryDate!);
      if (parsedExpiry != null) _doExpiryDate = parsedExpiry;
    }

    final initialDays = (widget.file.targetFreeDays != null && widget.file.targetFreeDays! > 0)
        ? widget.file.targetFreeDays!
        : null;
    _freeDaysAllowed = initialDays;
    _freeDaysController = TextEditingController(
      text: initialDays != null ? initialDays.toString() : '',
    );
    if (_doExpiryDate == null && initialDays != null) {
      _doExpiryDate = _doDate.add(Duration(days: initialDays));
    }

    _doNumberController = TextEditingController(
      text: widget.file.deliveryOrderNo ?? '',
    );
    _feesController = TextEditingController();
    _paymentRefController = TextEditingController();
    _fileUrlController = TextEditingController();
    _notesController = TextEditingController();

    Future.microtask(() {
      ref.read(allPartnersProvider.notifier).fetchPartners();
    });
  }

  @override
  void dispose() {
    _doNumberController.dispose();
    _feesController.dispose();
    _paymentRefController.dispose();
    _fileUrlController.dispose();
    _notesController.dispose();
    _freeDaysController.dispose();
    super.dispose();
  }

  void _updateFreeDays() {
    if (_doExpiryDate == null) return;
    final diff = _doExpiryDate!.difference(_doDate).inDays;
    final val = diff > 0 ? diff : 0;
    setState(() {
      _freeDaysAllowed = val;
      _freeDaysController.text = val.toString();
    });
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_doExpiryDate == null) {
      messenger.showSnackBar(
        AppTheme.snackBar(context, l.requiredField, severity: AppSeverity.danger),
      );
      return;
    }

    final fees = double.tryParse(_feesController.text.trim());
    if (fees == null || fees < 0) {
      messenger.showSnackBar(
        AppTheme.snackBar(context, l.ccDoFeesInvalidSnack, severity: AppSeverity.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'import_file_id': widget.file.importFileId,
        'delivery_order_number': _doNumberController.text.trim(),
        'delivery_order_date': _doDate.toIso8601String(),
        'delivery_order_expiry': _doExpiryDate!.toIso8601String(),
        'free_days_allowed': int.tryParse(_freeDaysController.text.trim()) ?? _freeDaysAllowed,
        'shipping_agent_id': _selectedShippingAgentId,
        'shipping_agent_name': _selectedShippingAgentName,
        'delivery_order_fees': fees,
        'delivery_order_currency': _selectedCurrency,
        'delivery_order_payment_ref': _paymentRefController.text.trim(),
        'delivery_order_paid_at': _doDate.toIso8601String(),
        'delivery_order_file_url': _fileUrlController.text.trim().isEmpty
            ? null
            : _fileUrlController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };
      final successBar =
          AppTheme.snackBar(context, l.ccDoSuccess(_doNumberController.text), severity: AppSeverity.success);

      await ref
          .read(customsClearanceProvider.notifier)
          .recordDeliveryOrderPayment(payload);

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(successBar);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          AppTheme.snackBar(
            context,
            l.ccDoError(ApiErrorText.of(l, e)),
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

  InputDecoration _dec(String label, {String? hint, IconData? icon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  Widget _datePicker({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _dec(label, icon: icon),
          child: LtrText(
            value != null ? CcFormat.date(value) : '—',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final partnersAsync = ref.watch(allPartnersProvider);
    final file = widget.file;

    return CcStageDialogShell(
      title: l.ccDoTitle,
      icon: Icons.directions_boat_filled_rounded,
      accent: AppTheme.cobalt,
      maxWidth: 820,
      chips: [
        CcHeaderChip(Icons.folder_outlined, l.ccDoChipShipment(file.importFileCode, file.companyName)),
      ],
      confirmKey: const Key('submitDeliveryOrderBtn'),
      confirmLabel: l.ccDoConfirm,
      loadingLabel: l.ccDoConfirming,
      confirmIcon: Icons.check_circle_outline_rounded,
      confirmVariant: AppButtonVariant.primary,
      isSubmitting: _isSubmitting,
      onConfirm: _submitPayment,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status / informative banner
            Container(
              padding: const EdgeInsetsDirectional.all(14),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.cobaltBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.infoForeground, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ccDoStageTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.infoForeground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.ccDoStageDesc,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Shipment metadata chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (file.customFileNumber != null && file.customFileNumber!.isNotEmpty)
                  _buildInfoChip(Icons.folder_open_rounded, l.ccDoFileNoChip, file.customFileNumber!),
                if (file.supplierName.isNotEmpty)
                  _buildInfoChip(Icons.business_rounded, l.ccDoSupplierChip, file.supplierName),
                if (file.portOfDischarge != null && file.portOfDischarge!.isNotEmpty)
                  _buildInfoChip(Icons.anchor_rounded, l.ccDoPortChip, file.portOfDischarge!),
                if (_freeDaysAllowed != null)
                  _buildInfoChip(
                    Icons.timelapse_rounded,
                    l.ccDoFreeDaysChip,
                    l.ccDoDays(_freeDaysAllowed!),
                    color: _freeDaysAllowed! <= 3 ? AppTheme.crimson : AppTheme.emerald,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            CcFormSection(
              title: l.ccDoSection,
              icon: Icons.directions_boat_filled_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shipping line dropdown
                  partnersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text(
                      l.ccDoPartnersError(ApiErrorText.of(l, err)),
                      style: const TextStyle(color: AppTheme.crimson),
                    ),
                    data: (partners) {
                      final shippingLines = partners.where((p) {
                        final type = p.partnerType.toLowerCase();
                        return type.contains('shipping') ||
                            type.contains('line') ||
                            type.contains('agent') ||
                            type.contains('carrier') ||
                            type.contains('ملاح');
                      }).toList();

                      final availablePartners = shippingLines.isNotEmpty ? shippingLines : partners;

                      final items = availablePartners.map((p) {
                        return SearchableDropdownItem<int>(
                          value: p.providerId ?? 0,
                          label: p.partnerName,
                          subtitle: '${p.partnerType} • ${p.partnerCode}',
                          icon: Icons.directions_boat_filled_rounded,
                        );
                      }).toList();

                      return SearchableDropdownField<int>(
                        key: const Key('shippingAgentDropdown'),
                        value: _selectedShippingAgentId,
                        items: items,
                        labelText: l.ccDoAgentLabel,
                        hintText: l.ccDoAgentHint,
                        searchHintText: l.ccDoAgentSearchHint,
                        isRequired: true,
                        onChanged: (val) {
                          setState(() {
                            _selectedShippingAgentId = val;
                            final matched = availablePartners.firstWhere(
                              (p) => p.providerId == val,
                              orElse: () => availablePartners.first,
                            );
                            _selectedShippingAgentName = matched.partnerName;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // DO number
                  TextFormField(
                    key: const Key('doNumberField'),
                    controller: _doNumberController,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(l.ccDoNumberLabel,
                        hint: l.ccDoNumberHint, icon: Icons.confirmation_number_rounded),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccDoNumberRequired;
                      if (val.trim().length < 3) return l.ccDoNumberTooShort;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // D/O fee amount & currency
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: const Key('doFeesField'),
                          controller: _feesController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: _dec(l.ccDoFeesLabel, hint: '0.00', icon: Icons.payments_rounded),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return l.ccDoFeesRequired;
                            final numVal = double.tryParse(val.trim());
                            if (numVal == null || numVal < 0) return l.ccDoFeesInvalid;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableDropdownField<String>(
                          value: _selectedCurrency,
                          isDense: false,
                          isRequired: true,
                          labelText: l.ccDoCurrencyLabel,
                          decoration: _dec(l.ccDoCurrencyLabel),
                          items: _currencies
                              .map((c) => SearchableDropdownItem<String>(value: c, label: c))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCurrency = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment receipt no.
                  TextFormField(
                    key: const Key('paymentRefField'),
                    controller: _paymentRefController,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(l.ccDoPaymentRefLabel,
                        hint: l.ccDoPaymentRefHint, icon: Icons.receipt_long_rounded),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccDoPaymentRefRequired;
                      if (val.trim().length < 2) return l.ccDoPaymentRefTooShort;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dates: issue date & expiry date & free days
                  CcFieldRow(
                    gap: 12,
                    children: [
                      _datePicker(
                        label: l.ccDoDateLabel,
                        icon: Icons.calendar_today_rounded,
                        value: _doDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _doDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _doDate = picked;
                              _updateFreeDays();
                            });
                          }
                        },
                      ),
                      _datePicker(
                        label: l.ccDoExpiryLabel,
                        icon: Icons.event_busy_rounded,
                        value: _doExpiryDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _doExpiryDate ?? _doDate,
                            firstDate: _doDate,
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _doExpiryDate = picked;
                              _updateFreeDays();
                            });
                          }
                        },
                      ),
                      TextFormField(
                        key: const Key('freeDaysField'),
                        controller: _freeDaysController,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _dec(l.ccDoFreeDaysChip, hint: '14', icon: Icons.timelapse_rounded),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return l.fbkConfirmFreeDaysRequired;
                          final numVal = int.tryParse(val.trim());
                          if (numVal == null || numVal < 0) return l.fbkValidatorFreeDays;
                          return null;
                        },
                        onChanged: (val) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed != null && parsed >= 0) {
                            setState(() {
                              _freeDaysAllowed = parsed;
                              _doExpiryDate = _doDate.add(Duration(days: parsed));
                            });
                          } else {
                            setState(() {
                              _freeDaysAllowed = null;
                              _doExpiryDate = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    key: const Key('fileUrlField'),
                    controller: _fileUrlController,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(
                      l.ccDoFileUrlLabel,
                      hint: 'https://storage.sorourlogistics.com/docs/do_scan.pdf',
                      icon: Icons.attach_file_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    key: const Key('notesField'),
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _dec(l.ccDoNotesLabel, hint: l.ccDoNotesHint, icon: Icons.notes_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, {Color? color}) {
    final chipColor = color ?? AppTheme.cobalt;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
