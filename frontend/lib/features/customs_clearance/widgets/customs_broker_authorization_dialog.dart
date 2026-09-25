import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../providers/customs_clearance_provider.dart';

/// Modal dialog for CS-01: Customs Broker Electronic Authorization
/// تعيين المخلص الجمركي والتفويض الإلكتروني
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
    final isArabic = context.l10n.isArabic;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrokerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى اختيار المخلص الجمركي المعتمد' : 'Please select an approved customs broker'),
          backgroundColor: AppTheme.crimson,
        ),
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

      await ref.read(customsClearanceProvider.notifier).authorizeBroker(payload);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تم تعيين وتفويض المخلص الجمركي بنجاح برقم (${_delegationNoController.text.trim()})'
                        : 'Customs broker successfully assigned and authorized (#${_delegationNoController.text.trim()})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.crimson,
            content: Text(isArabic ? 'فشل تفويض المخلص الجمركي: $e' : 'Failed to authorize customs broker: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPartnersAsync = ref.watch(allPartnersProvider);
    final isArabic = context.l10n.isArabic;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_ind_rounded,
                      color: Color(0xFF7C3AED),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'تعيين المخلص الجمركي والتفويض الإلكتروني (CS-01)' : '(CS-01) Assign Customs Broker & E-Authorization',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.file.primaryNameWithCode} • ${isArabic ? 'المورد:' : 'Supplier:'} ${widget.file.supplierName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Scrollable Form Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isArabic
                                    ? 'توليد تفويض المخلص إلكترونياً واعتماده عبر منصة نافذة، مع رفع تقدم الشحنة لـ 80% وجدولة مهمة سداد إذن التسليم الملاحي (CS-02).'
                                    : 'Generate customs broker authorization electronically and approve via Nafeza, advancing shipment progress to 80% and scheduling delivery order payment task (CS-02).',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF5B21B6),
                                  height: 1.4,
                                ),
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
                                ? '${isArabic ? 'رخصة:' : 'Lic:'} ${b.clearanceLicenseNumber}'
                                : '';
                            final ports = b.authorizedPorts != null && b.authorizedPorts!.isNotEmpty
                                ? ' | ${isArabic ? 'موانئ:' : 'Ports:'} ${b.authorizedPorts}'
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
                            labelText: isArabic ? 'المخلص الجمركي المعين *' : 'Assigned Customs Broker *',
                            hintText: isArabic ? 'اختر المخلص الجمركي المعتمد...' : 'Select approved customs broker...',
                            searchHintText: isArabic ? 'ابحث باسم المخلص أو رقم الرخصة أو الميناء...' : 'Search by broker name, license, or port...',
                            onChanged: (val) {
                              setState(() {
                                _selectedBrokerId = val;
                              });
                            },
                            validator: (val) => val == null || val == 0
                                ? (isArabic ? 'يرجى اختيار المخلص الجمركي المعتمد' : 'Please select an approved customs broker')
                                : null,
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isArabic ? 'خطأ في تحميل قائمة المخلصين: $err' : 'Error loading customs brokers: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 2. Electronic Delegation Number & Generator
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('delegationNumberField'),
                              controller: _delegationNoController,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'رقم التفويض الإلكتروني (Nafeza / MTS Code) *' : 'Electronic Authorization No. (Nafeza / MTS Code) *',
                                hintText: isArabic ? 'مثال: DEL-2026-ALEX-01 أو MTS-AUTH-...' : 'e.g., DEL-2026-ALEX-01 or MTS-AUTH-...',
                                prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      tooltip: isArabic ? 'نسخ رقم التفويض' : 'Copy authorization number',
                                      onPressed: () {
                                        if (_delegationNoController.text.trim().isNotEmpty) {
                                          Clipboard.setData(ClipboardData(text: _delegationNoController.text.trim()));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(isArabic ? 'تم نسخ رقم التفويض إلى الحافظة' : 'Authorization number copied to clipboard')),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF7C3AED), size: 20),
                                      tooltip: isArabic ? 'توليد رقم تفويض آلي جديد' : 'Generate new auto authorization number',
                                      onPressed: _generateDelegationNumber,
                                    ),
                                  ],
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return isArabic ? 'رقم التفويض الإلكتروني إلزامي' : 'Electronic authorization number is required';
                                }
                                if (val.trim().length < 3) {
                                  return isArabic ? 'رقم التفويض يجب ألا يقل عن 3 أحرف' : 'Authorization number must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 3. Delegation Date & Customs Office
                      Row(
                        children: [
                          // Delegation Date
                          Expanded(
                            child: InkWell(
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
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'تاريخ التفويض الإلكتروني' : 'Electronic Authorization Date',
                                  prefixIcon: const Icon(Icons.calendar_month_rounded, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                child: Text(
                                  '${_delegationDate.year}-${_delegationDate.month.toString().padLeft(2, '0')}-${_delegationDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Customs Office Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: const Key('customsOfficeDropdown'),
                              value: _selectedCustomsOffice,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'الميناء الجمركي المعني' : 'Relevant Customs Port / Office',
                                prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              items: _customsOffices
                                  .map((o) => DropdownMenuItem(
                                        value: o,
                                        child: Text(
                                          o,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCustomsOffice = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 4. Checkbox for Formal Mandate Letter
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
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
                            isArabic ? 'توليد خطاب تفويض جمركي رسمي (Customs Broker Mandate Letter)' : 'Generate Official Mandate Letter (Customs Broker Mandate Letter)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isArabic ? 'إنشاء خطاب التوكيل والتفويض تلقائياً باسم مدير عام جمارك الميناء لحفظه في أرشيف الخطابات الرسمية.' : 'Automatically generate mandate letter addressed to Port Customs Director General for official archive.',
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                          activeColor: const Color(0xFF7C3AED),
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
                        decoration: InputDecoration(
                          labelText: isArabic ? 'ملاحظات وتوجيهات للمستخلص (اختياري)' : 'Instructions & Notes for Broker (Optional)',
                          hintText: isArabic ? 'مثال: سداد إذن التسليم فور الوصول، متابعة لجنة الفحص المشترك GOEIC...' : 'e.g. Pay delivery order upon arrival, follow up with GOEIC inspection...',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    key: const Key('confirmBrokerAuthorizationBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.verified_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? (isArabic ? 'جاري الاعتماد والتفويض...' : 'Authorizing...')
                          : (isArabic ? 'اعتماد وتفويض المخلص (CS-01)' : '(CS-01) Approve & Authorize Broker'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _isSubmitting ? null : _submitAuthorization,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
