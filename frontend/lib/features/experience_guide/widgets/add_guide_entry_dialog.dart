import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/experience_guide_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/widgets.dart';

class AddGuideEntryDialog extends ConsumerStatefulWidget {
  final String? initialHsCode;
  final String? initialCategory;
  final String? initialDestinationPort;
  final String? initialPortOfLoading;
  final String? initialSupplier;
  final String? initialCountryOfOrigin;
  final String? initialShippingLine;
  final String? initialIncoterm;
  final String? initialPaymentMethod;
  final String? initialCertificateType;
  final String? initialCustomsBroker;
  final String? initialSeasonTiming;
  final String? initialImportFileReference;

  final String? initialTitle;
  final String? initialContent;
  final String? initialSeverity;
  final String? initialDepartment;
  final VoidCallback? onSuccess;

  const AddGuideEntryDialog({
    super.key,
    this.initialHsCode,
    this.initialCategory,
    this.initialDestinationPort,
    this.initialPortOfLoading,
    this.initialSupplier,
    this.initialCountryOfOrigin,
    this.initialShippingLine,
    this.initialIncoterm,
    this.initialPaymentMethod,
    this.initialCertificateType,
    this.initialCustomsBroker,
    this.initialSeasonTiming,
    this.initialImportFileReference,
    this.initialTitle,
    this.initialContent,
    this.initialSeverity,
    this.initialDepartment,
    this.onSuccess,
  });

  @override
  ConsumerState<AddGuideEntryDialog> createState() => _AddGuideEntryDialogState();
}

class _AddGuideEntryDialogState extends ConsumerState<AddGuideEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String _entryType = 'required_document';
  String _severity = 'critical';
  String _department = 'Logistics';
  DateTime? _expiresAt;
  bool _isSubmitting = false;

  final List<Map<String, String>> _scopes = [];

  static const List<Map<String, String>> _scopeTypes = [
    {'value': 'supplier', 'label': 'المورد الأجنبي (Supplier)'},
    {'value': 'hs_code', 'label': 'البند الجمركي (HS Code)'},
    {'value': 'product_category', 'label': 'فئة المنتج (Category)'},
    {'value': 'country_of_origin', 'label': 'بلد المنشأ (Country of Origin)'},
    {'value': 'port_of_loading', 'label': 'ميناء الشحن (POL)'},
    {'value': 'port_of_discharge', 'label': 'ميناء الوصول (POD)'},
    {'value': 'shipping_line', 'label': 'الخط الملاحي (Carrier)'},
    {'value': 'incoterm', 'label': 'شرط التسليم (Incoterm)'},
    {'value': 'payment_method', 'label': 'طريقة الدفع (Payment Method)'},
    {'value': 'certificate_type', 'label': 'نوع الشهادة (Certificate)'},
    {'value': 'customs_broker', 'label': 'المخلص الجمركي (Broker)'},
    {'value': 'season_timing', 'label': 'الموسم / التوقيت (Season)'},
    {'value': 'import_file_reference', 'label': 'ملف الاستيراد (Import File)'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    if (widget.initialSeverity != null && widget.initialSeverity!.isNotEmpty) {
      _severity = widget.initialSeverity!;
    }
    if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) {
      _department = widget.initialDepartment!;
    }

    // Pre-seed scopes from shipment parameters if provided
    void addIfValid(String type, String? val) {
      if (val != null && val.trim().isNotEmpty) {
        _scopes.add({'scope_type': type, 'scope_value': val.trim()});
      }
    }

    addIfValid('supplier', widget.initialSupplier);
    addIfValid('hs_code', widget.initialHsCode);
    addIfValid('product_category', widget.initialCategory);
    addIfValid('country_of_origin', widget.initialCountryOfOrigin);
    addIfValid('port_of_loading', widget.initialPortOfLoading);
    addIfValid('port_of_discharge', widget.initialDestinationPort);
    addIfValid('shipping_line', widget.initialShippingLine);
    addIfValid('incoterm', widget.initialIncoterm);
    addIfValid('payment_method', widget.initialPaymentMethod);
    addIfValid('certificate_type', widget.initialCertificateType);
    addIfValid('customs_broker', widget.initialCustomsBroker);
    addIfValid('season_timing', widget.initialSeasonTiming);
    addIfValid('import_file_reference', widget.initialImportFileReference);

    if (_scopes.isEmpty) {
      _scopes.add({'scope_type': 'supplier', 'scope_value': ''});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _addScope() {
    setState(() {
      _scopes.add({'scope_type': 'hs_code', 'scope_value': ''});
    });
  }

  void _removeScope(int index) {
    setState(() {
      _scopes.removeAt(index);
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 1825)), // 5 years
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Filter valid scopes
    final validScopes = _scopes
        .where((s) => (s['scope_value'] ?? '').trim().isNotEmpty)
        .map((s) => {
              'scope_type': s['scope_type'],
              'scope_value': s['scope_value']!.trim(),
            })
        .toList();

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'entry_type': _entryType,
        'severity': _severity,
        'department': _department,
        if (_expiresAt != null) 'expires_at': _expiresAt!.toIso8601String(),
        'created_by': ref.read(authProvider).user?.fullName ?? 'system',
        'scopes': validScopes,
      };

      await ref.read(experienceGuideProvider.notifier).createEntry(payload);

      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.guideEntrySavedSuccess),
        );
        if (widget.onSuccess != null) widget.onSuccess!();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'حدث خطأ أثناء حفظ التوجيه: $e'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_outlined, color: AppTheme.flatCobalt, size: 26),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.addGuideEntryBtn,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.flatCharcoal,
                              ),
                            ),
                            const Text(
                              'توثيق تجربة تشغيلية أو درس مستفاد في بنك المعرفة المؤسسية',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l10n.guideEntryTitleLabel,
                            hintText: 'مثال: اشتراطات المورد سوزو يوهينغ أو ميناء الإسكندرية',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال عنوان التوجيه';
                            }
                            if (val.trim().length < 3) {
                              return 'العنوان يجب أن يتكون من 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Content
                        TextFormField(
                          controller: _contentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l10n.guideEntryContentLabel,
                            hintText: 'اكتب تفاصيل الدرس المستفاد أو التوجيه، والمستندات الإلزامية أو المشكلات السابقة...',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال تفاصيل التوجيه والاشتراطات';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Dropdowns: Severity, Type, Department
                        Row(
                          children: [
                            // Severity
                            Expanded(
                              flex: 3,
                              child: SearchableDropdownField<String>(
                                value: _severity,
                                labelText: l10n.guideSeverityLabel,
                                decoration: InputDecoration(
                                  labelText: l10n.guideSeverityLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                items: const [
                                  SearchableDropdownItem<String>(
                                    value: 'critical',
                                    label: 'حرج / مانع للخطأ',
                                    icon: Icons.dangerous_rounded,
                                  ),
                                  SearchableDropdownItem<String>(
                                    value: 'warning',
                                    label: 'تحذير تشغيلي',
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                  SearchableDropdownItem<String>(
                                    value: 'info',
                                    label: 'معلومة إرشادية',
                                    icon: Icons.info_outline,
                                  ),
                                  SearchableDropdownItem<String>(
                                    value: 'positive',
                                    label: 'أفضل ممارسة / نجاح',
                                    icon: Icons.verified_rounded,
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _severity = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Type
                            Expanded(
                              flex: 3,
                              child: SearchableDropdownField<String>(
                                value: _entryType,
                                labelText: l10n.guideEntryTypeLabel,
                                decoration: InputDecoration(
                                  labelText: l10n.guideEntryTypeLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                items: const [
                                  SearchableDropdownItem<String>(value: 'required_document', label: 'مستند إلزامي مسبق'),
                                  SearchableDropdownItem<String>(value: 'alert', label: 'تنبيه إجرائي'),
                                  SearchableDropdownItem<String>(value: 'task', label: 'مهمة متابعة إجبارية'),
                                  SearchableDropdownItem<String>(value: 'info', label: 'معلومة استرشادية'),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _entryType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Department
                            Expanded(
                              flex: 2,
                              child: SearchableDropdownField<String>(
                                value: _department,
                                labelText: 'القسم المعني',
                                decoration: const InputDecoration(
                                  labelText: 'القسم المعني',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  SearchableDropdownItem<String>(value: 'Logistics', label: 'اللوجستيات'),
                                  SearchableDropdownItem<String>(value: 'Customs', label: 'الجمارك'),
                                  SearchableDropdownItem<String>(value: 'Finance', label: 'المالية'),
                                  SearchableDropdownItem<String>(value: 'Quality', label: 'الجودة'),
                                  SearchableDropdownItem<String>(value: 'Management', label: 'الإدارة'),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _department = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Expiry Date (Optional)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickExpiryDate,
                                borderRadius: BorderRadius.circular(6),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'تاريخ انتهاء السريان (اختياري)',
                                    hintText: 'صالح دائماً (غير محدد)',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.event_outlined),
                                    suffixIcon: _expiresAt != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () => setState(() => _expiresAt = null),
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    _expiresAt != null
                                        ? '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}'
                                        : 'صالح دائماً وبلا تاريخ انتهاء',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _expiresAt != null ? AppTheme.flatCharcoal : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Scopes Section (Multi-Dimensional Tagging)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.guideScopesHeader,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.flatCharcoal,
                                  ),
                                ),
                                const Text(
                                  'أبعاد وشروط التطابق الذاتي (13 بعداً تشغيلياً)',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add_circle_outline, size: 16),
                              label: Text(l10n.guideAddScopeBtn, style: const TextStyle(fontSize: 12)),
                              onPressed: _addScope,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ..._scopes.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final scope = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 210,
                                  child: SearchableDropdownField<String>(
                                    value: scope['scope_type'],
                                    labelText: '',
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _scopeTypes.map((st) {
                                      return SearchableDropdownItem<String>(
                                        value: st['value']!,
                                        label: st['label']!,
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _scopes[idx]['scope_type'] = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: scope['scope_value'],
                                    decoration: const InputDecoration(
                                      hintText: 'قيمة النطاق (مثال: سوزو يوهينغ، الإسكندرية...)',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      _scopes[idx]['scope_value'] = val;
                                    },
                                  ),
                                ),
                                if (_scopes.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.flatCrimson, size: 20),
                                    onPressed: () => _removeScope(idx),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 20),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.flatCobalt,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
