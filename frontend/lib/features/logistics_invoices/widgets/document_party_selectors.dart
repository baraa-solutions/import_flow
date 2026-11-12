import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';

/// Required, searchable import-file picker for logistics documents (advances, insurance policies).
/// Starts empty unless the caller passes a file: a document is never silently put on a default file.
class ImportFileSelectField extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?>? onChanged;
  final bool isArabic;

  const ImportFileSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = (ref.watch(importFilesProvider).valueOrNull ?? const []).where((f) => f.isActive);
    return SearchableDropdownField<int>(
      value: value,
      labelText: isArabic ? 'ملف الشحنة *' : 'Import File *',
      hintText: isArabic ? 'اختر ملف الشحنة' : 'Select the import file',
      isRequired: true,
      validator: (v) => v == null ? (isArabic ? 'مطلوب' : 'Required') : null,
      items: files
          .map((f) => SearchableDropdownItem<int>(
                value: f.importFileId,
                label: f.importFileCode,
                subtitle: f.supplierName,
                searchValue: '${f.importFileCode} ${f.customFileNumber ?? ''} ${f.supplierName} ${f.projectNames ?? ''}',
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Required, searchable partner picker limited to the partner types a document accepts
/// (e.g. customs brokers for a clearance advance, insurers for a policy).
class PartnerSelectField extends ConsumerWidget {
  final int? value;
  final ValueChanged<PartnerModel?> onChanged;
  final String label;
  final bool isArabic;

  /// Case-insensitive fragments matched against [PartnerModel.partnerType].
  final List<String> typeKeywords;

  const PartnerSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.isArabic,
    required this.typeKeywords,
  });

  static bool matchesType(PartnerModel p, List<String> keywords) {
    final type = p.partnerType.toLowerCase();
    return keywords.any((k) => type.contains(k.toLowerCase()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partners = (ref.watch(allPartnersProvider).valueOrNull ?? const <PartnerModel>[])
        .where((p) => p.providerId != null && p.isActive && matchesType(p, typeKeywords))
        .toList();
    return SearchableDropdownField<int>(
      value: value,
      labelText: '$label *',
      isRequired: true,
      validator: (v) => v == null ? (isArabic ? 'مطلوب' : 'Required') : null,
      items: partners
          .map((p) => SearchableDropdownItem<int>(value: p.providerId!, label: p.partnerName, subtitle: p.partnerType))
          .toList(),
      onChanged: (id) => onChanged(partners.where((p) => p.providerId == id).firstOrNull),
    );
  }
}
