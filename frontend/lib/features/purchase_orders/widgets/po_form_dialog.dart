import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../../core/widgets/change_diff_dialog.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/widgets/tariff_form_dialog.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_companies/models/import_company_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../incoterms/providers/incoterms_provider.dart';
import '../../incoterms/models/incoterm_model.dart';
import '../../projects/providers/projects_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../../suppliers/models/supplier_model.dart';
import '../models/purchase_order_model.dart';
import '../providers/purchase_orders_provider.dart';
import 'dart:async';
import 'po_reconciliation_warning_dialog.dart';
import '../../../core/widgets/concurrency_conflict_dialog.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../services/po_draft_manager.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/container_load_plan_painter.dart';
import '../../../core/services/container_load_plan_export_service.dart';
import '../../currencies/models/currency_model.dart';
import 'po_report_preview_dialog.dart';
import '../utils/po_packing_matcher.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../../core/widgets/table_row_clone_helper.dart';


import 'package:frontend/core/widgets/ltr_text.dart';
class POFormDialog extends ConsumerStatefulWidget {
  final PurchaseOrderModel? po;
  final Map<String, dynamic>? initialExtractedFields;

  const POFormDialog({super.key, this.po, this.initialExtractedFields});

  @override
  ConsumerState<POFormDialog> createState() => _POFormDialogState();
}

class _POFormDialogState extends ConsumerState<POFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _poReferenceCtrl;
  late TextEditingController _piCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _notesCtrl;

  late DateTime _selectedOrderDate;
  int? _selectedImportFileId;
  int? _selectedProjectId;
  int? _selectedCompanyId;
  int? _selectedSupplierId;
  int? _selectedIncotermId;
  int? _selectedCurrencyId;
  String? _selectedCountryOfOrigin;
  late String _selectedStatus;
  late String _selectedPaymentTerms;

  static String? normalizeCountryName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim().toUpperCase();
    final match = countryOptions.where((c) {
      final code = c['code']!.toUpperCase();
      final name = c['name']!.toUpperCase();
      return code == clean || name.contains(clean) || clean.contains(code) || 
             (clean == 'LITHUANIA' && (code == 'LT' || name.contains('LITHUANIA') || name.contains('ليتوانيا'))) || 
             (clean == 'ITALY' && (code == 'IT' || name.contains('ITALY') || name.contains('إيطاليا'))) || 
             (clean == 'CHINA' && (code == 'CN' || name.contains('CHINA') || name.contains('الصين')));
    }).firstOrNull;
    return match != null ? match['name'] : raw;
  }

  static const List<Map<String, String>> countryOptions = [
    {'code': 'CN', 'name': 'CN - الصين (China)'},
    {'code': 'DE', 'name': 'DE - ألمانيا (Germany)'},
    {'code': 'IT', 'name': 'IT - إيطاليا (Italy)'},
    {'code': 'LT', 'name': 'LT - ليتوانيا (Lithuania)'},
    {'code': 'TW', 'name': 'TW - تايوان (Taiwan)'},
    {'code': 'TR', 'name': 'TR - تركيا (Turkey)'},
    {'code': 'FR', 'name': 'FR - فرنسا (France)'},
    {'code': 'ES', 'name': 'ES - إسبانيا (Spain)'},
    {'code': 'GB', 'name': 'GB - المملكة المتحدة (United Kingdom)'},
    {'code': 'US', 'name': 'US - الولايات المتحدة الأمريكية (USA)'},
    {'code': 'BR', 'name': 'BR - البرازيل (Brazil)'},
    {'code': 'AR', 'name': 'AR - الأرجنتين (Argentina)'},
    {'code': 'IN', 'name': 'IN - الهند (India)'},
    {'code': 'JP', 'name': 'JP - اليابان (Japan)'},
    {'code': 'KR', 'name': 'KR - كوريا الجنوبية (South Korea)'},
    {'code': 'SA', 'name': 'SA - المملكة العربية السعودية (Saudi Arabia)'},
    {'code': 'AE', 'name': 'AE - الإمارات العربية المتحدة (UAE)'},
    {'code': 'JO', 'name': 'JO - الأردن (Jordan)'},
    {'code': 'MA', 'name': 'MA - المغرب (Morocco)'},
    {'code': 'TN', 'name': 'TN - تونس (Tunisia)'},
    {'code': 'LB', 'name': 'LB - لبنان (Lebanon)'},
    {'code': 'NL', 'name': 'NL - هولندا (Netherlands)'},
    {'code': 'BE', 'name': 'BE - بلجيكا (Belgium)'},
    {'code': 'AT', 'name': 'AT - النمسا (Austria)'},
    {'code': 'PL', 'name': 'PL - بولندا (Poland)'},
    {'code': 'SE', 'name': 'SE - السويد (Sweden)'},
    {'code': 'CH', 'name': 'CH - سويسرا (Switzerland)'},
    {'code': 'RU', 'name': 'RU - روسيا (Russia)'},
    {'code': 'VN', 'name': 'VN - فيتنام (Vietnam)'},
    {'code': 'TH', 'name': 'TH - تايلاند (Thailand)'},
    {'code': 'MY', 'name': 'MY - ماليزيا (Malaysia)'},
    {'code': 'ID', 'name': 'ID - إندونيسيا (Indonesia)'},
    {'code': 'EG', 'name': 'EG - مصر (Egypt)'},
  ];

  late List<POLineItemModel> _dialogItems;
  late List<PackingListItemModel> _dialogPackingItems;
  late List<PalletPlanItemModel> _dialogPalletItems;
  bool _isSubmitting = false;
  bool _isDirectVolumeMode = false;
  int _palletCount = 0;
  String _selectedPalletType = 'Euro Pallet (120x80)';
  bool _isPalletStackable = false;
  double _palletLengthCm = 120.0;
  double _palletWidthCm = 80.0;
  double _palletHeightCm = 150.0;

  void _cloneLineItem(int index) {
    if (index < 0 || index >= _dialogItems.length) return;
    final original = _dialogItems[index];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    const copySuffix = TableRowCloneHelper.copySuffix;
    final duplicated = original.copyWith(
      itemId: null,
      itemCode: original.itemCode != null && original.itemCode!.trim().isNotEmpty
          ? '${original.itemCode}${TableRowCloneHelper.copyCodeSuffix}'
          : null,
      mainDescription: original.mainDescription != null && original.mainDescription!.trim().isNotEmpty
          ? '${original.mainDescription}$copySuffix'
          : null,
      descriptionAr: '${original.descriptionAr}$copySuffix',
      descriptionEn: original.descriptionEn != null ? '${original.descriptionEn}$copySuffix' : null,
    );
    setState(() {
      _dialogItems.insert(index + 1, duplicated);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAr ? 'تم استنساخ سطر الفاتورة بنجاح' : 'Invoice line item cloned successfully'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clonePackingItem(int index) {
    if (index < 0 || index >= _dialogPackingItems.length) return;
    final original = _dialogPackingItems[index];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    const copySuffix = TableRowCloneHelper.copySuffix;
    final duplicated = original.copyWith(
      packingItemId: null,
      itemCode: '${original.itemCode}${TableRowCloneHelper.copyCodeSuffix}',
      mainDescription: original.mainDescription != null && original.mainDescription!.trim().isNotEmpty
          ? '${original.mainDescription}$copySuffix'
          : null,
      description: original.description != null && original.description!.trim().isNotEmpty
          ? '${original.description}$copySuffix'
          : null,
    );
    setState(() {
      _dialogPackingItems.insert(index + 1, duplicated);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAr ? 'تم استنساخ طرد الباكينج ليست بنجاح' : 'Packing list item cloned successfully'),
        backgroundColor: AppTheme.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<CustomsTariffModel?> _showHsCodeSearchPicker(BuildContext context, List<CustomsTariffModel> tariffs) async {
    return showDialog<CustomsTariffModel?>(
      context: context,
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = tariffs.where((t) {
              final query = search.trim().toLowerCase();
              if (query.isEmpty) return true;
              return t.hsCode.toLowerCase().contains(query) ||
                  t.hsDescription.toLowerCase().contains(query) ||
                  t.categorySearchText.contains(query);
            }).toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.search, color: AppTheme.cobalt),
                  SizedBox(width: 8),
                  Text('اختيار البند الجمركي (Customs Tariff / HS Code)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم البند الجمركي أو الوصف (مثال: 8415 أو تكييف)...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setDialogState(() => search = ''),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() => search = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة لمفتاح البحث'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final item = filtered[i];
                                return ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobalt.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: LtrText(
                                          item.hsCode,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.hsDescription,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'الفئة: ${item.categoryLabelArabic ?? "عام"} | جمارك: ${item.customsDutyRate}% | قيمة مضافة: ${item.vatRate}% | رسم تنمية: ${item.developmentFeeRate}%',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(ctx, item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('إلغاء'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateExchangeRateFromCurrency(int? currencyId, List<CurrencyModel> currencies) {
    if (currencyId == null) return;
    final curr = currencies.where((c) => c.currencyId == currencyId).firstOrNull;
    if (curr == null) return;
    if (curr.isBaseCurrency || curr.currencyCode == 'EGP') {
      _rateCtrl.text = '1.0';
      return;
    }

    double? foundRate;
    if (curr.exchangeRates != null && curr.exchangeRates!.isNotEmpty) {
      final orderDateStr = _selectedOrderDate.toString().substring(0, 10);
      final sortedRates = List.from(curr.exchangeRates!)
        ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
      final matching = sortedRates.firstWhere(
        (r) => r.effectiveDate.compareTo(orderDateStr) <= 0,
        orElse: () => sortedRates.first,
      );
      foundRate = matching.commercialRate;
    }

    foundRate ??= curr.latestCommercialRate;
    if (foundRate != null && foundRate > 0) {
      _rateCtrl.text = foundRate.toString();
    }
  }

  int _numToInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  double _numToDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  DateTime _parseFlexDate(String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return DateTime.now();
    final s = rawStr.trim();
    final parsedIso = DateTime.tryParse(s);
    if (parsedIso != null) return parsedIso;

    final parts = s.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]) ?? 1;
      final p1 = int.tryParse(parts[1]) ?? 1;
      final p2 = int.tryParse(parts[2]) ?? DateTime.now().year;
      if (p2 > 1000) {
        return DateTime(p2, p1, p0);
      } else if (p0 > 1000) {
        return DateTime(p0, p1, p2);
      }
    }
    return DateTime.now();
  }

  dynamic _getExt(Map<String, dynamic> ext, List<String> candidateKeys) {
    for (final ck in candidateKeys) {
      if (ext.containsKey(ck) && ext[ck] != null && ext[ck].toString().trim().isNotEmpty) {
        return ext[ck];
      }
    }
    final normExt = ext.map((k, v) => MapEntry(k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), ''), v));
    for (final ck in candidateKeys) {
      final normCk = ck.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
      if (normExt.containsKey(normCk) && normExt[normCk] != null && normExt[normCk].toString().trim().isNotEmpty) {
        return normExt[normCk];
      }
    }
    return null;
  }

  void _applyExtractedData(Map<String, dynamic> ext) {
    setState(() {
      final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
      final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
      final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
      final currencies = ref.read(currenciesProvider).valueOrNull ?? [];

      if (ext['order_date'] != null || ext['po_date'] != null || ext['date'] != null) {
        _selectedOrderDate = _parseFlexDate((ext['order_date'] ?? ext['po_date'] ?? ext['date'])?.toString());
      }
      final piNum = (ext['po_number'] ?? ext['proforma_invoice_number'] ?? ext['pi_number'] ?? ext['invoice_number'])?.toString();
      if (piNum != null && piNum.trim().isNotEmpty) {
        _piCtrl.text = piNum.trim();
      }
      final poRef = (ext['po_reference'] ?? ext['reference'] ?? ext['order_title'] ?? ext['subject'] ?? ext['po_title'])?.toString();
      if (poRef != null && poRef.trim().isNotEmpty) {
        _poReferenceCtrl.text = poRef.trim();
      }

      final rawCty = _getExt(ext, ['country_of_origin', 'origin_country', 'supplier_country', 'country'])?.toString().trim();
      if (rawCty != null && rawCty.isNotEmpty) {
        _selectedCountryOfOrigin = normalizeCountryName(rawCty);
      }

      final compId = _matchCompanyId(ext, companies);
      if (compId != null) _selectedCompanyId = compId;

      final suppId = _matchSupplierId(ext, suppliers);
      if (suppId != null) _selectedSupplierId = suppId;

      final incoId = _matchIncotermId(ext, incoterms);
      if (incoId != null) _selectedIncotermId = incoId;

      final currId = _matchCurrencyId(ext, currencies);
      if (currId != null) {
        _selectedCurrencyId = currId;
        _updateExchangeRateFromCurrency(_selectedCurrencyId, currencies);
      }

      if (ext['pallet_count'] != null) {
        _palletCount = _numToInt(ext['pallet_count']);
        if (_palletCount > 0) _isDirectVolumeMode = true;
      }
      if (ext['pallet_type'] != null) {
        _selectedPalletType = ext['pallet_type'].toString();
      }
      if (ext['is_pallet_stackable'] != null) {
        _isPalletStackable = ext['is_pallet_stackable'] as bool? ?? false;
      }

      // Line items
      if ((ext['items'] is List && (ext['items'] as List).isNotEmpty) || (ext['line_items'] is List && (ext['line_items'] as List).isNotEmpty)) {
        final extTopHs = (ext['hs_code'] ?? ext['customs_tariff'] ?? ext['hsCode'])?.toString().trim();
        final itemList = (ext['items'] is List && (ext['items'] as List).isNotEmpty) ? (ext['items'] as List) : (ext['line_items'] as List);
        _dialogItems = itemList.asMap().entries.map((entry) {
          final idx = entry.key;
          final i = Map<String, dynamic>.from(entry.value as Map);
          final qty = (i['quantity'] as num?)?.toDouble() ?? 100.0;
          final price = (i['unit_price'] as num?)?.toDouble() ?? 10.0;
          final desc = i['commercial_name']?.toString() ?? i['description']?.toString() ?? i['item_name']?.toString() ?? i['name']?.toString() ?? 'بند استيرادي رئيسي';
          final codeRaw = i['item_code'] ?? i['item_number'] ?? i['item_no'] ?? i['code'];
          final code = (codeRaw != null && codeRaw.toString().trim().isNotEmpty)
              ? codeRaw.toString().trim()
              : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}';
          final rawHs = (i['hs_code'] != null && i['hs_code'].toString().trim().isNotEmpty)
              ? i['hs_code'].toString().trim()
              : extTopHs;

          int? matchedTariffId;
          String? matchedHsCode = rawHs;
          if (rawHs != null && rawHs.trim().isNotEmpty && tariffs.isNotEmpty) {
            final cleanHs = rawHs.replaceAll(RegExp(r'[^\d]'), '');
            final matched = tariffs.where((t) {
              final tClean = t.hsCode.replaceAll(RegExp(r'[^\d]'), '');
              return tClean == cleanHs || (cleanHs.length >= 4 && (tClean.startsWith(cleanHs) || cleanHs.startsWith(tClean)));
            }).firstOrNull;
            if (matched != null) {
              matchedTariffId = matched.tariffId;
              matchedHsCode = matched.hsCode;
            }
          }

          return POLineItemModel(
            itemCode: code,
            mainDescription: i['main_description']?.toString(),
            descriptionAr: desc,
            descriptionEn: desc,
            countryOfOrigin: _selectedCountryOfOrigin,
            tariffId: matchedTariffId,
            hsCode: matchedHsCode,
            quantity: qty > 0 ? qty : 100.0,
            unitPrice: price > 0 ? price : 10.0,
            cbmPerUnit: (i['cbm_per_unit'] as num?)?.toDouble() ?? 0.1,
            grossWeightKg: (i['gross_weight_kg'] as num?)?.toDouble() ?? 5.0,
            netWeightKg: (i['net_weight_kg'] as num?)?.toDouble() ?? 4.5,
          );
        }).toList();
      }

      // Packing list items
      if ((ext['packing_list_items'] is List && (ext['packing_list_items'] as List).isNotEmpty) || (ext['packing_list'] is List && (ext['packing_list'] as List).isNotEmpty)) {
        final packingList = (ext['packing_list_items'] is List && (ext['packing_list_items'] as List).isNotEmpty) ? (ext['packing_list_items'] as List) : (ext['packing_list'] as List);
        _dialogPackingItems = packingList.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = Map<String, dynamic>.from(entry.value as Map);
          String? pDesc = p['description']?.toString() ?? p['item_name']?.toString();
          if ((pDesc == null || pDesc.trim().isEmpty) && idx < _dialogItems.length) {
            pDesc = _dialogItems[idx].descriptionAr;
          }
          final hsCode = p['hs_code']?.toString() ?? (idx < _dialogItems.length ? _dialogItems[idx].hsCode ?? '' : '');
          final itemCode = p['item_code']?.toString() ?? (idx < _dialogItems.length ? _dialogItems[idx].itemCode ?? '' : '');
          return PackingListItemModel(
            hsCode: hsCode,
            itemCode: itemCode,
            mainDescription: p['main_description']?.toString(),
            description: pDesc,
            qtyPcs: (p['qty_pcs'] ?? p['quantity'] as num?)?.toDouble() ?? 1.0,
            qtyPkg: (p['qty_pkg'] ?? p['package_count'] ?? p['quantity'] as num?)?.toDouble() ?? 1.0,
            packageType: p['package_type']?.toString() ?? 'Carton',
            unit: p['unit']?.toString() ?? 'PCS',
            lengthCm: (p['length_cm'] as num?)?.toDouble() ?? 100.0,
            widthCm: (p['width_cm'] as num?)?.toDouble() ?? 80.0,
            heightCm: (p['height_cm'] as num?)?.toDouble() ?? 60.0,
            netWeightUnitKg: (p['net_weight_unit_kg'] as num?)?.toDouble() ?? 10.0,
            grossWeightUnitKg: (p['gross_weight_unit_kg'] as num?)?.toDouble() ?? 12.0,
            totalGrossWeightKg: (p['total_gross_weight_kg'] ?? p['gross_weight_kg'] as num?)?.toDouble() ?? 12.0,
            totalNetWeightKg: (p['total_net_weight_kg'] ?? p['net_weight_kg'] as num?)?.toDouble() ?? 10.0,
            totalCbm: (p['total_cbm'] ?? p['cbm'] as num?)?.toDouble() ?? 0.48,
            isStackable: p['is_stackable'] as bool? ?? true,
          );
        }).toList();
      }
    });

    final docNum = ext['po_number'] ?? ext['proforma_invoice_number'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم استخلاص وتغذية بيانات الفاتورة المبدئية ($docNum) وقائمة التعبئة بنجاح'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  int? _matchCompanyId(Map<String, dynamic> ext, List<ImportCompanyModel> companies) {
    final rawComp = _getExt(ext, ['importer_name', 'importer name', 'company_name', 'company name', 'importer', 'company', 'consignee', 'client_name'])?.toString().trim().toLowerCase();
    final rawCompTax = _getExt(ext, ['importer_tax_id', 'importer tax id', 'tax_id', 'vat_id'])?.toString().trim();
    if (rawComp == null || rawComp.isEmpty) return null;

    final matchedComp = companies.where((c) {
      final cName = c.importerName.toLowerCase();
      final cTax = c.vatId.trim();
      if (rawCompTax != null && rawCompTax.isNotEmpty && (cTax == rawCompTax || cTax.replaceAll(RegExp(r'[^\d]'), '') == rawCompTax.replaceAll(RegExp(r'[^\d]'), ''))) return true;
      if (cName.contains(rawComp) || rawComp.contains(cName)) return true;
      final noise = {'trading', 'contracting', 'for', 'and', 'co', 'ltd', 'llc', 'corp', 'spa', 'gmbh', 'sae', 's.a.e', 'group', 'the', '&'};
      final rawTokens = rawComp.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final cTokens = cName.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final intersection = rawTokens.intersection(cTokens);
      return intersection.isNotEmpty && (intersection.length >= 2 || intersection.length == rawTokens.length || intersection.length == cTokens.length);
    }).firstOrNull;

    return matchedComp?.companyId;
  }

  int? _matchSupplierId(Map<String, dynamic> ext, List<SupplierModel> suppliers) {
    final rawSupp = _getExt(ext, ['supplier_name', 'supplier name', 'supplier', 'vendor_name', 'vendor name', 'vendor', 'shipper', 'exporter_name', 'exporter name', 'exporter'])?.toString().trim().toLowerCase();
    final rawSuppTax = _getExt(ext, ['supplier_tax_id', 'supplier tax id', 'exporter_id', 'vat_number', 'tax_id'])?.toString().trim();
    final rawSuppEmail = _getExt(ext, ['supplier_email', 'supplier email', 'email'])?.toString().trim().toLowerCase();
    if (rawSupp == null || rawSupp.isEmpty) return null;

    final matchedSupp = suppliers.where((s) {
      final sName = s.companyName.toLowerCase();
      final sTax = s.foreignExporterId.trim();
      final sEmail = s.email?.trim().toLowerCase();
      if (rawSuppTax != null && rawSuppTax.isNotEmpty && (sTax == rawSuppTax || sTax.replaceAll(RegExp(r'[^\d]'), '') == rawSuppTax.replaceAll(RegExp(r'[^\d]'), ''))) return true;
      if (rawSuppEmail != null && rawSuppEmail.isNotEmpty && sEmail == rawSuppEmail) return true;
      if (sName.contains(rawSupp) || rawSupp.contains(sName)) return true;
      final noise = {'ltd', 'inc', 'corp', 'spa', 'gmbh', 'international', 'co.', 'co', 'the', '&', 'group', 'uab'};
      final rawTokens = rawSupp.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final sTokens = sName.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final intersection = rawTokens.intersection(sTokens);
      return intersection.isNotEmpty && (intersection.isNotEmpty || intersection.length == rawTokens.length || intersection.length == sTokens.length);
    }).firstOrNull;

    return matchedSupp?.supplierId;
  }

  int? _matchIncotermId(dynamic extOrRaw, List<IncotermModel> incoterms) {
    if (incoterms.isEmpty) return null;
    String raw = '';
    if (extOrRaw is Map<String, dynamic>) {
      final val = _getExt(extOrRaw, ['incoterms', 'incoterm', 'trade_terms', 'terms', 'delivery_terms', 'shipment_terms']);
      if (val != null) raw = val.toString().trim().toUpperCase();
    } else if (extOrRaw != null) {
      raw = extOrRaw.toString().trim().toUpperCase();
    }
    if (raw.isEmpty) return null;

    final numId = int.tryParse(raw);
    if (numId != null && incoterms.any((i) => i.incotermId == numId)) {
      return numId;
    }

    for (final i in incoterms) {
      final code = i.incotermCode.toUpperCase().trim();
      if (code == raw) return i.incotermId;
    }

    if (raw.contains('FOB') || raw.contains('FREE ON BOARD')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'FOB').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('EXW') || raw.contains('EX WORK') || raw.contains('EX-WORK') || raw.contains('EX WORKS')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'EXW').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('CIF') || raw.contains('COST INSURANCE')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'CIF').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('CFR') || raw.contains('C&F') || raw.contains('CNF') || raw.contains('COST AND FREIGHT')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'CFR').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('CIP') || raw.contains('CARRIAGE AND INSURANCE')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'CIP').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('CPT') || raw.contains('CARRIAGE PAID')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'CPT').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('DAP') || raw.contains('DELIVERED AT PLACE')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'DAP').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('DDP') || raw.contains('DELIVERED DUTY PAID')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'DDP').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('DPU') || raw.contains('DELIVERED AT PLACE UNLOADED')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'DPU').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('FCA') || raw.contains('FREE CARRIER')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'FCA').firstOrNull;
      if (f != null) return f.incotermId;
    }
    if (raw.contains('FAS') || raw.contains('FREE ALONGSIDE')) {
      final f = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'FAS').firstOrNull;
      if (f != null) return f.incotermId;
    }

    for (final i in incoterms) {
      final code = i.incotermCode.toUpperCase().trim();
      if (raw.contains(code)) return i.incotermId;
    }

    return null;
  }

  int? _matchCurrencyId(dynamic extOrRaw, List<CurrencyModel> currencies) {
    if (currencies.isEmpty) return null;
    String raw = '';
    if (extOrRaw is Map<String, dynamic>) {
      final val = _getExt(extOrRaw, ['currency', 'currency_code', 'curr', 'currency_symbol', 'invoice_currency', 'price_currency']);
      if (val != null) raw = val.toString().trim().toUpperCase();
    } else if (extOrRaw != null) {
      raw = extOrRaw.toString().trim().toUpperCase();
    }
    if (raw.isEmpty) return null;

    final numId = int.tryParse(raw);
    if (numId != null && currencies.any((c) => c.currencyId == numId)) {
      return numId;
    }

    for (final c in currencies) {
      final code = c.currencyCode.toUpperCase().trim();
      if (code == raw) return c.currencyId;
    }

    if (raw == '\$' || raw.contains('USD') || raw.contains('DOLLAR') || raw.contains('US DOLLAR') || raw.contains('دولار')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'USD').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw == '€' || raw.contains('EUR') || raw.contains('EURO') || raw.contains('يورو')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'EUR').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw == 'LE' || raw == 'L.E' || raw == 'L.E.' || raw.contains('EGP') || raw.contains('POUND EGYPTIAN') || raw.contains('EGYPTIAN POUND') || raw.contains('جنيه') || raw.contains('ج.م')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'EGP').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw == '£' || raw.contains('GBP') || raw.contains('STERLING') || raw.contains('إسترليني')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'GBP').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw == '¥' || raw.contains('CNY') || raw.contains('RMB') || raw.contains('YUAN') || raw.contains('يوان')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'CNY').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw.contains('SAR') || raw.contains('RIYAL') || raw.contains('ريال')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'SAR').firstOrNull;
      if (c != null) return c.currencyId;
    }

    if (raw.contains('AED') || raw.contains('DIRHAM') || raw.contains('درهم')) {
      final c = currencies.where((curr) => curr.currencyCode.toUpperCase().trim() == 'AED').firstOrNull;
      if (c != null) return c.currencyId;
    }

    for (final c in currencies) {
      final code = c.currencyCode.toUpperCase().trim();
      if (raw.contains(code)) return c.currencyId;
    }

    return null;
  }

  static String _formatDecimalInput(double val) {
    if (val.isNaN || val.isInfinite) return '0';
    if (val == 0.0) return '0';
    final rounded = val.roundToDouble();
    if ((val - rounded).abs() < 0.0005) {
      return rounded.toInt().toString();
    }
    var s = val.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _applyExtractedFieldsToState(Map<String, dynamic> ext, {String targetTab = 'all'}) {
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];

    if (!mounted) return;
    setState(() {
      if (targetTab == 'invoice' || targetTab == 'all') {
        final poNum = ext['po_number']?.toString() ?? ext['proforma_invoice_number']?.toString();
        if (poNum != null && poNum.isNotEmpty) {
          _piCtrl.text = poNum;
        }
        final poRef = (ext['po_reference'] ?? ext['reference'] ?? ext['order_title'] ?? ext['subject'])?.toString();
        if (poRef != null && poRef.isNotEmpty) {
          _poReferenceCtrl.text = poRef;
        }
        final dateStr = (ext['order_date'] ?? ext['po_date'] ?? ext['date'])?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          _selectedOrderDate = _parseFlexDate(dateStr);
        }

        // 1. Company Matching (الشركة المستوردة)
        final matchedCompanyId = _matchCompanyId(ext, companies);
        if (matchedCompanyId != null) {
          _selectedCompanyId = matchedCompanyId;
        }

        // 2. Supplier Matching (المورد الأجنبي)
        final matchedSupplierId = _matchSupplierId(ext, suppliers);
        if (matchedSupplierId != null) {
          _selectedSupplierId = matchedSupplierId;
        }

        // 3. Incoterm Matching (شروط التعاقد)
        final matchedIncoId = _matchIncotermId(ext, incoterms);
        if (matchedIncoId != null) {
          _selectedIncotermId = matchedIncoId;
        }

        // 4. Currency Matching (العملة)
        final matchedCurrId = _matchCurrencyId(ext, currencies);
        if (matchedCurrId != null) {
          _selectedCurrencyId = matchedCurrId;
          _updateExchangeRateFromCurrency(_selectedCurrencyId, currencies);
        }

        // 5. Country of Origin (بلد المنشأ)
        final rawCty = _getExt(ext, ['country_of_origin', 'country of origin', 'origin_country', 'supplier_country', 'supplier country', 'country'])?.toString().trim().toUpperCase();
        if (rawCty != null && rawCty.isNotEmpty) {
          final matchedCty = countryOptions.where((c) =>
            c['code'] == rawCty ||
            c['name']!.toUpperCase().contains(rawCty) ||
            (rawCty == 'LT' && (c['code'] == 'LT' || c['name']!.contains('Lithuania') || c['name']!.contains('ليتوانيا'))) ||
            (rawCty == 'CN' && (c['code'] == 'CN' || c['name']!.contains('China') || c['name']!.contains('الصين'))) ||
            (rawCty == 'IT' && (c['code'] == 'IT' || c['name']!.contains('Italy') || c['name']!.contains('إيطاليا')))
          ).firstOrNull;
          if (matchedCty != null) {
            _selectedCountryOfOrigin = matchedCty['name'];
          }
        }

        // 6. Payment Terms (شروط الدفع)
        final rawTerms = (ext['payment_terms'] ?? ext['payment_condition'] ?? ext['terms_of_payment'])?.toString().toUpperCase();
        if (rawTerms != null && rawTerms.isNotEmpty) {
          if (rawTerms.contains('LC') || rawTerms.contains('LETTER OF CREDIT') || rawTerms.contains('اعتماد')) {
            _selectedPaymentTerms = 'Letter of Credit / LC';
          } else if (rawTerms.contains('PREPAYMENT') || rawTerms.contains('AVV.MERCE') || rawTerms.contains('SWIFT') || rawTerms.contains('CASH') || rawTerms.contains('T/T') || rawTerms.contains('سويفت') || rawTerms.contains('مقدم')) {
            _selectedPaymentTerms = 'Cash in Advance / SWIFT';
          } else if (rawTerms.contains('CAD') || rawTerms.contains('COLLECTION') || rawTerms.contains('مستندات')) {
            _selectedPaymentTerms = 'Cash Against Documents / CAD';
          } else if (rawTerms.contains('OPEN ACCOUNT') || rawTerms.contains('حساب مفتوح')) {
            _selectedPaymentTerms = 'Open Account';
          }
        }

        if (ext['pallet_count'] != null) {
          final pCount = _numToInt(ext['pallet_count']);
          if (pCount > 0) {
            _palletCount = pCount;
            _isDirectVolumeMode = true;
          }
        }
        if (ext['is_pallet_stackable'] != null) {
          _isPalletStackable = ext['is_pallet_stackable'] as bool? ?? false;
        }

        final extTopHs = (ext['hs_code'] ?? ext['customs_tariff'] ?? ext['hsCode'])?.toString().trim();

        if (ext['items'] is List && (ext['items'] as List).isNotEmpty) {
          final itemList = ext['items'] as List;
          _dialogItems = itemList.asMap().entries.map((entry) {
            final idx = entry.key;
            final raw = entry.value;
            final i = Map<String, dynamic>.from(raw as Map);
            final qty = (i['quantity'] as num?)?.toDouble() ?? 100.0;
            final price = (i['unit_price'] as num?)?.toDouble() ?? 10.0;
            final desc = i['description']?.toString() ?? i['item_name']?.toString() ?? i['name']?.toString() ?? i['description_ar']?.toString() ?? i['description_en']?.toString() ?? 'بند استيرادي رئيسي';
            final codeRaw = i['item_code'] ?? i['item_number'] ?? i['item_no'] ?? i['product_code'] ?? i['code'] ?? i['item'];
            final code = (codeRaw != null && codeRaw.toString().trim().isNotEmpty)
                ? codeRaw.toString().trim()
                : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}';
            final rawHs = (i['hs_code'] != null && i['hs_code'].toString().trim().isNotEmpty)
                ? i['hs_code'].toString().trim()
                : (extTopHs != null && extTopHs.isNotEmpty ? extTopHs : null);

            String? itemCty = i['country_of_origin']?.toString() ?? i['country']?.toString();
            if (itemCty != null && itemCty.isNotEmpty) {
              itemCty = normalizeCountryName(itemCty);
            } else {
              itemCty = normalizeCountryName(_selectedCountryOfOrigin);
            }

            int? matchedTariffId;
            String? matchedHsCode = rawHs;
            if (rawHs != null && rawHs.trim().isNotEmpty && tariffs.isNotEmpty) {
              final cleanHs = rawHs.replaceAll(RegExp(r'[^\d]'), '');
              final matched = tariffs.where((t) {
                final tClean = t.hsCode.replaceAll(RegExp(r'[^\d]'), '');
                return tClean == cleanHs ||
                    (cleanHs.length >= 4 && (tClean.startsWith(cleanHs) || cleanHs.startsWith(tClean))) ||
                    (cleanHs.length >= 6 && tClean.startsWith(cleanHs.substring(0, 6))) ||
                    (cleanHs.length >= 4 && tClean.startsWith(cleanHs.substring(0, 4)));
              }).firstOrNull;
              if (matched != null) {
                matchedTariffId = matched.tariffId;
                matchedHsCode = matched.hsCode;
              }
            }

            return POLineItemModel(
              itemCode: code,
              descriptionAr: desc,
              descriptionEn: desc,
              countryOfOrigin: itemCty,
              tariffId: matchedTariffId,
              hsCode: matchedHsCode,
              quantity: qty > 0 ? qty : 100.0,
              unitPrice: price > 0 ? price : 10.0,
              cbmPerUnit: (i['cbm_per_unit'] as num?)?.toDouble() ?? 0.1,
              grossWeightKg: (i['gross_weight_kg'] as num?)?.toDouble() ?? 5.0,
              netWeightKg: (i['net_weight_kg'] as num?)?.toDouble() ?? 4.5,
            );
          }).toList();
        }
      }

      if (targetTab == 'packing' || targetTab == 'all') {
        final packingList = ext['packing_list_items'] is List && (ext['packing_list_items'] as List).isNotEmpty
            ? ext['packing_list_items'] as List
            : (ext['items'] is List ? ext['items'] as List : []);

        if (packingList.isNotEmpty) {
          _dialogPackingItems = packingList.asMap().entries.map((entry) {
            final idx = entry.key;
            final raw = entry.value;
            final p = Map<String, dynamic>.from(raw as Map);
            final qtyPcs = (p['qty_pcs'] ?? p['quantity'] as num?)?.toDouble() ?? 10.0;
            final qtyPkg = (p['qty_pkg'] as num?)?.toDouble() ?? (qtyPcs > 0 ? (qtyPcs / 10).ceilToDouble() : 1.0);
            String? pDesc = p['description']?.toString() ?? p['item_name']?.toString() ?? p['name']?.toString();
            if ((pDesc == null || pDesc.trim().isEmpty) && idx < _dialogItems.length) {
              pDesc = _dialogItems[idx].descriptionAr.isNotEmpty ? _dialogItems[idx].descriptionAr : _dialogItems[idx].descriptionEn;
            }
            final pTotCbm = (p['total_cbm'] ?? p['volume'] ?? p['cbm'] as num?)?.toDouble() ?? 0.0;
            final pUnit = p['unit']?.toString() ?? 'cm';
            final pWeightUnit = p['weight_unit']?.toString() ?? 'KGM';
            final pCodeRaw = p['item_code'] ?? p['item_number'] ?? p['item_no'] ?? p['product_code'] ?? p['code'] ?? p['item'];
            final pCode = (pCodeRaw != null && pCodeRaw.toString().trim().isNotEmpty)
                ? pCodeRaw.toString().trim()
                : (idx < _dialogItems.length && _dialogItems[idx].itemCode != null && _dialogItems[idx].itemCode!.isNotEmpty
                    ? _dialogItems[idx].itemCode!
                    : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}');

            String pHs = (p['hs_code'] != null && p['hs_code'].toString().trim().isNotEmpty) ? p['hs_code'].toString().trim() : '';
            if (pHs.isEmpty && idx < _dialogItems.length && _dialogItems[idx].hsCode != null && _dialogItems[idx].hsCode!.isNotEmpty) {
              pHs = _dialogItems[idx].hsCode!;
            } else if (pHs.isEmpty && idx < _dialogItems.length && _dialogItems[idx].tariffId != null) {
              final match = tariffs.where((t) => t.tariffId == _dialogItems[idx].tariffId).firstOrNull;
              if (match != null) pHs = match.hsCode;
            } else if (pHs.isEmpty && ext['hs_code'] != null) {
              pHs = ext['hs_code'].toString().trim();
            }

            return PackingListItemModel(
              hsCode: pHs,
              itemCode: pCode,
              description: pDesc,
              qtyPcs: qtyPcs,
              qtyPkg: qtyPkg,
              packageType: p['package_type']?.toString() ?? 'Carton',
              unit: pUnit,
              weightUnit: pWeightUnit,
              lengthCm: (p['length_cm'] as num?)?.toDouble() ?? 0.0,
              widthCm: (p['width_cm'] as num?)?.toDouble() ?? 0.0,
              heightCm: (p['height_cm'] as num?)?.toDouble() ?? 0.0,
              grossWeightUnitKg: (p['gross_weight_unit_kg'] ?? p['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
              netWeightUnitKg: (p['net_weight_unit_kg'] ?? p['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
              totalGrossWeightKg: (p['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
              totalNetWeightKg: (p['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0,
              totalCbm: pTotCbm,
              isStackable: p['is_stackable'] as bool? ?? true,
            );
          }).toList();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(projectsProvider.notifier).fetchProjects();
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
      ref.read(suppliersProvider.notifier).fetchSuppliers();
      ref.read(incotermsProvider.notifier).fetchIncoterms();
      ref.read(currenciesProvider.notifier).fetchCurrencies();
      ref.read(customsTariffProvider.notifier).fetchTariffs();
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });

    final po = widget.po;
    final ext = widget.initialExtractedFields;
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];

    _selectedOrderDate = po?.orderDate ??
        (ext != null ? _parseFlexDate((ext['order_date'] ?? ext['po_date'] ?? ext['date'])?.toString()) : DateTime.now());

    final defaultPiNumber = po?.proformaInvoiceNumber ??
        (ext != null ? (ext['po_number'] ?? ext['proforma_invoice_number'] ?? ext['pi_number'] ?? ext['invoice_number'])?.toString() : null) ?? '';
    final defaultPoRef = po?.poReference ??
        (ext != null ? (ext['po_reference'] ?? ext['reference'] ?? ext['order_title'] ?? ext['subject'] ?? ext['po_title'])?.toString() : null) ?? '';
    _piCtrl = TextEditingController(text: defaultPiNumber);
    _poReferenceCtrl = TextEditingController(text: defaultPoRef);
    _rateCtrl = TextEditingController(text: (po?.exchangeRate ?? 1.0).toString());
    _notesCtrl = TextEditingController(text: po?.notes ?? '');
    _selectedStatus = po?.status ?? 'Draft';
    _palletCount = po?.palletCount ?? (ext != null ? _numToInt(ext['pallet_count']) : 0);
    _selectedPalletType = po?.palletType ?? (ext != null ? ext['pallet_type']?.toString() : null) ?? 'Euro Pallet (120x80)';
    _isPalletStackable = po?.isPalletStackable ?? (ext != null ? (ext['is_pallet_stackable'] as bool? ?? false) : false);
    _palletLengthCm = po?.palletLengthCm ?? (ext != null ? _numToDouble(ext['pallet_length_cm'], 120.0) : 120.0);
    _palletWidthCm = po?.palletWidthCm ?? (ext != null ? _numToDouble(ext['pallet_width_cm'], 80.0) : 80.0);
    _palletHeightCm = po?.palletHeightCm ?? (ext != null ? _numToDouble(ext['pallet_height_cm'], 150.0) : 150.0);
    
    if (po != null && po.palletPlanItems.isNotEmpty) {
      _dialogPalletItems = List.from(po.palletPlanItems);
      _isDirectVolumeMode = true;
    } else if (_palletCount > 0) {
      _dialogPalletItems = [
        PalletPlanItemModel(
          palletType: _selectedPalletType,
          palletCount: _palletCount,
          lengthCm: _palletLengthCm,
          widthCm: _palletWidthCm,
          heightCm: _palletHeightCm,
          isStackable: _isPalletStackable,
        )
      ];
      _isDirectVolumeMode = true;
    } else {
      _dialogPalletItems = [];
      _isDirectVolumeMode = false;
    }

    final rawTerms = po?.paymentTerms ?? (ext != null ? ext['payment_terms']?.toString() : null);
    if (rawTerms != null && (rawTerms.contains('LC') || rawTerms.contains('اعتماد') || rawTerms.contains('CREDIT'))) {
      _selectedPaymentTerms = 'Letter of Credit / LC';
    } else if (rawTerms != null && (rawTerms.contains('SWIFT') || rawTerms.contains('Cash') || rawTerms.contains('سويفت') || rawTerms.contains('T/T') || rawTerms.contains('CHK') || rawTerms.contains('DBT'))) {
      _selectedPaymentTerms = 'Cash in Advance / SWIFT';
    } else {
      _selectedPaymentTerms = rawTerms ?? 'Cash in Advance / SWIFT';
    }

    _selectedImportFileId = po?.importFileId;
    _selectedProjectId = po?.projectId;
    _selectedCompanyId = po?.companyId;
    _selectedSupplierId = po?.supplierId;
    _selectedIncotermId = po?.incotermId;
    _selectedCurrencyId = po?.currencyId;
    _selectedCountryOfOrigin = normalizeCountryName(po?.countryOfOrigin);

    if (po != null && po.items.isNotEmpty) {
      _dialogItems = po.items.map((i) => POLineItemModel(
            itemCode: i.itemCode,
            mainDescription: i.mainDescription,
            descriptionAr: i.descriptionAr,
            descriptionEn: i.descriptionEn,
            countryOfOrigin: i.countryOfOrigin,
            tariffId: i.tariffId,
            quantity: i.quantity,
            unitOfMeasure: i.unitOfMeasure,
            unitPrice: i.unitPrice,
            cbmPerUnit: i.cbmPerUnit,
            grossWeightKg: i.grossWeightKg,
            netWeightKg: i.netWeightKg,
          )).toList();
    } else if (ext != null && ((ext['items'] is List && (ext['items'] as List).isNotEmpty) || (ext['line_items'] is List && (ext['line_items'] as List).isNotEmpty))) {
      final extTopHs = (ext['hs_code'] ?? ext['customs_tariff'] ?? ext['hsCode'])?.toString().trim();
      final itemList = (ext['items'] is List && (ext['items'] as List).isNotEmpty) ? (ext['items'] as List) : (ext['line_items'] as List);
      _dialogItems = itemList.asMap().entries.map((entry) {
        final idx = entry.key;
        final raw = entry.value;
        final i = Map<String, dynamic>.from(raw as Map);
        final qty = (i['quantity'] as num?)?.toDouble() ?? 100.0;
        final price = (i['unit_price'] as num?)?.toDouble() ?? 10.0;
        final desc = i['commercial_name']?.toString() ?? i['description']?.toString() ?? i['item_name']?.toString() ?? i['name']?.toString() ?? i['description_ar']?.toString() ?? i['description_en']?.toString() ?? 'بند استيرادي رئيسي';
        final mainDesc = i['main_description']?.toString() ?? i['mainDescription']?.toString();
        final codeRaw = i['item_code'] ?? i['item_number'] ?? i['item_no'] ?? i['product_code'] ?? i['code'] ?? i['item'];
        final code = (codeRaw != null && codeRaw.toString().trim().isNotEmpty)
            ? codeRaw.toString().trim()
            : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}';
        final rawHs = (i['hs_code'] != null && i['hs_code'].toString().trim().isNotEmpty)
            ? i['hs_code'].toString().trim()
            : (extTopHs != null && extTopHs.isNotEmpty ? extTopHs : null);

        String? itemCty = i['country_of_origin']?.toString() ?? i['country']?.toString();
        if (itemCty != null && itemCty.isNotEmpty) {
          final matchedCty = countryOptions.where((c) => c['code'] == itemCty?.toUpperCase() || c['name']!.toUpperCase().contains(itemCty!.toUpperCase())).firstOrNull;
          if (matchedCty != null) itemCty = matchedCty['code'];
        } else {
          itemCty = _selectedCountryOfOrigin;
        }

        int? matchedTariffId;
        String? matchedHsCode = rawHs;
        if (rawHs != null && rawHs.trim().isNotEmpty && tariffs.isNotEmpty) {
          final cleanHs = rawHs.replaceAll(RegExp(r'[^\d]'), '');
          final matched = tariffs.where((t) {
            final tClean = t.hsCode.replaceAll(RegExp(r'[^\d]'), '');
            return tClean == cleanHs ||
                (cleanHs.length >= 4 && (tClean.startsWith(cleanHs) || cleanHs.startsWith(tClean))) ||
                (cleanHs.length >= 6 && tClean.startsWith(cleanHs.substring(0, 6))) ||
                (cleanHs.length >= 4 && tClean.startsWith(cleanHs.substring(0, 4)));
          }).firstOrNull;
          if (matched != null) {
            matchedTariffId = matched.tariffId;
            matchedHsCode = matched.hsCode;
          }
        }

        return POLineItemModel(
          itemCode: code,
          mainDescription: mainDesc,
          descriptionAr: desc,
          descriptionEn: desc,
          countryOfOrigin: itemCty,
          tariffId: matchedTariffId,
          hsCode: matchedHsCode,
          quantity: qty > 0 ? qty : 100.0,
          unitPrice: price > 0 ? price : 10.0,
          cbmPerUnit: (i['cbm_per_unit'] as num?)?.toDouble() ?? 0.1,
          grossWeightKg: (i['gross_weight_kg'] as num?)?.toDouble() ?? 5.0,
          netWeightKg: (i['net_weight_kg'] as num?)?.toDouble() ?? 4.5,
        );
      }).toList();
    } else {
      _dialogItems = [
        POLineItemModel(
          descriptionAr: 'بند استيرادي رئيسي 1',
          quantity: 100,
          unitPrice: 10,
          cbmPerUnit: 0.1,
        )
      ];
    }

    final extTopHs = (ext != null) ? (ext['hs_code'] ?? ext['customs_tariff'] ?? ext['hsCode'])?.toString().trim() : null;

    if (po != null && po.packingListItems.isNotEmpty) {
      _dialogPackingItems = po.packingListItems.map((p) => PackingListItemModel(
            hsCode: p.hsCode,
            itemCode: p.itemCode,
            mainDescription: p.mainDescription,
            description: p.description,
            qtyPcs: p.qtyPcs,
            qtyPkg: p.qtyPkg,
            packageType: p.packageType,
            unit: p.unit,
            weightUnit: p.weightUnit,
            lengthCm: p.lengthCm,
            widthCm: p.widthCm,
            heightCm: p.heightCm,
            netWeightUnitKg: p.netWeightUnitKg,
            grossWeightUnitKg: p.grossWeightUnitKg,
            totalGrossWeightKg: p.totalGrossWeightKg,
            totalNetWeightKg: p.totalNetWeightKg,
            totalCbm: p.totalCbm,
            isStackable: p.isStackable,
          )).toList();
    } else if (ext != null && ((ext['packing_list_items'] is List && (ext['packing_list_items'] as List).isNotEmpty) || (ext['packing_list'] is List && (ext['packing_list'] as List).isNotEmpty))) {
      final packingList = (ext['packing_list_items'] is List && (ext['packing_list_items'] as List).isNotEmpty) ? (ext['packing_list_items'] as List) : (ext['packing_list'] as List);
      _dialogPackingItems = packingList.asMap().entries.map((entry) {
        final idx = entry.key;
        final raw = entry.value;
        final p = Map<String, dynamic>.from(raw as Map);
        String? pDesc = p['description']?.toString() ?? p['item_name']?.toString() ?? p['name']?.toString();
        if ((pDesc == null || pDesc.trim().isEmpty) && idx < _dialogItems.length) {
          pDesc = _dialogItems[idx].descriptionAr.isNotEmpty ? _dialogItems[idx].descriptionAr : _dialogItems[idx].descriptionEn;
        }
        String? pMainDesc = p['main_description']?.toString() ?? p['mainDescription']?.toString() ?? (idx < _dialogItems.length ? _dialogItems[idx].mainDescription : null);
        final pTotCbm = (p['total_cbm'] ?? p['volume'] ?? p['cbm'] as num?)?.toDouble() ?? 0.0;
        final pCodeRaw = p['item_code'] ?? p['item_number'] ?? p['item_no'] ?? p['product_code'] ?? p['code'] ?? p['item'];
        final pCode = (pCodeRaw != null && pCodeRaw.toString().trim().isNotEmpty)
            ? pCodeRaw.toString().trim()
            : (idx < _dialogItems.length && _dialogItems[idx].itemCode != null && _dialogItems[idx].itemCode!.isNotEmpty
                ? _dialogItems[idx].itemCode!
                : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}');

        String pHs = (p['hs_code'] != null && p['hs_code'].toString().trim().isNotEmpty) ? p['hs_code'].toString().trim() : '';
        if (pHs.isEmpty && idx < _dialogItems.length && _dialogItems[idx].hsCode != null && _dialogItems[idx].hsCode!.isNotEmpty) {
          pHs = _dialogItems[idx].hsCode!;
        } else if (pHs.isEmpty && idx < _dialogItems.length && _dialogItems[idx].tariffId != null) {
          final match = tariffs.where((t) => t.tariffId == _dialogItems[idx].tariffId).firstOrNull;
          if (match != null) pHs = match.hsCode;
        } else if (pHs.isEmpty && extTopHs != null && extTopHs.isNotEmpty) {
          pHs = extTopHs;
        }

        return PackingListItemModel(
          hsCode: pHs,
          itemCode: pCode,
          mainDescription: pMainDesc,
          description: pDesc,
          qtyPcs: (p['qty_pcs'] ?? p['quantity'] as num?)?.toDouble() ?? 1.0,
          qtyPkg: (p['qty_pkg'] ?? p['package_count'] ?? p['quantity'] as num?)?.toDouble() ?? 1.0,
          packageType: p['package_type']?.toString() ?? 'Carton',
          unit: p['unit']?.toString() ?? 'cm',
          weightUnit: p['weight_unit']?.toString() ?? 'KGM',
          lengthCm: (p['length_cm'] as num?)?.toDouble() ?? 0.0,
          widthCm: (p['width_cm'] as num?)?.toDouble() ?? 0.0,
          heightCm: (p['height_cm'] as num?)?.toDouble() ?? 0.0,
          grossWeightUnitKg: (p['gross_weight_unit_kg'] as num?)?.toDouble() ?? 0.0,
          netWeightUnitKg: (p['net_weight_unit_kg'] as num?)?.toDouble() ?? 0.0,
          totalGrossWeightKg: (p['total_gross_weight_kg'] ?? p['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
          totalNetWeightKg: (p['total_net_weight_kg'] ?? p['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
          totalCbm: pTotCbm,
          isStackable: p['is_stackable'] as bool? ?? true,
        );
      }).toList();
    } else {
      _dialogPackingItems = _dialogItems.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final desc = item.descriptionAr.isNotEmpty ? item.descriptionAr : item.descriptionEn;
        return PackingListItemModel(
          hsCode: item.hsCode ?? '',
          itemCode: (item.itemCode != null && item.itemCode!.trim().isNotEmpty)
              ? item.itemCode!.trim()
              : 'ITEM-${(idx + 1).toString().padLeft(3, '0')}',
          mainDescription: item.mainDescription,
          description: desc,
          qtyPcs: item.quantity,
          qtyPkg: (item.quantity > 0 ? (item.quantity / 10).ceilToDouble() : 10.0),
          packageType: 'Carton',
          lengthCm: 50.0,
          widthCm: 40.0,
          heightCm: 30.0,
          netWeightUnitKg: item.netWeightKg > 0 ? item.netWeightKg : 5.0,
          grossWeightUnitKg: item.grossWeightKg > 0 ? item.grossWeightKg : 6.0,
        );
      }).toList();
    }

    _poReferenceCtrl.addListener(_markDirty);
    _piCtrl.addListener(_markDirty);
    _rateCtrl.addListener(_markDirty);
    _notesCtrl.addListener(_markDirty);

    _autosaveTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isDirty && mounted) {
        _performAutosave();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkExistingDraft();
        _loadPoGuide();
      }
    });
  }

  bool _isDirty = false;
  DateTime? _lastDraftSavedAt;
  Timer? _autosaveTimer;

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<void> _performAutosave() async {
    if (!mounted) return;
    try {
      final draftData = {
        'po_reference': _poReferenceCtrl.text,
        'pi_number': _piCtrl.text,
        'exchange_rate': _rateCtrl.text,
        'notes': _notesCtrl.text,
        'order_date': _selectedOrderDate.toIso8601String(),
        'import_file_id': _selectedImportFileId,
        'project_id': _selectedProjectId,
        'company_id': _selectedCompanyId,
        'supplier_id': _selectedSupplierId,
        'incoterm_id': _selectedIncotermId,
        'currency_id': _selectedCurrencyId,
        'country_of_origin': _selectedCountryOfOrigin,
        'status': _selectedStatus,
        'payment_terms': _selectedPaymentTerms,
        'pallet_count': _palletCount,
        'pallet_type': _selectedPalletType,
        'is_pallet_stackable': _isPalletStackable,
        'items': _dialogItems.map((i) => i.toJson()).toList(),
        'packing_items': _dialogPackingItems.map((p) => p.toJson()).toList(),
      };
      await PODraftManager.saveDraft(
        poId: widget.po?.poId,
        draftData: draftData,
      );
      if (mounted) {
        setState(() {
          _lastDraftSavedAt = DateTime.now();
        });
      }
    } catch (_) {}
  }

  Future<void> _checkExistingDraft() async {
    final draft = await PODraftManager.loadDraft(widget.po?.poId);
    if (draft == null || !mounted) return;
    final savedAt = draft['saved_at']?.toString() ?? '';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (!mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text(isAr ? 'استعادة مسودة غير محفوظة' : 'Restore Unsaved Draft'),
          ],
        ),
        content: Text(
          isAr
              ? 'توجد مسودة غير محفوظة تم حفظها تلقائياً لهذه الشاشة ($savedAt).\nهل ترغب في استعادة البيانات غير المحفوظة؟'
              : 'An autosaved draft exists for this Purchase Order ($savedAt).\nDo you want to restore the unsaved changes?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              PODraftManager.clearDraft(widget.po?.poId);
              Navigator.of(ctx).pop(false);
            },
            child: Text(isAr ? 'تجاهل وحذف المسودة' : 'Discard Draft'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isAr ? 'استعادة المسودة' : 'Restore Draft'),
          ),
        ],
      ),
    );

    if (restore == true && mounted) {
      _applyDraftData(draft);
    }
  }

  void _applyDraftData(Map<String, dynamic> draft) {
    setState(() {
      if (draft['po_reference'] != null) _poReferenceCtrl.text = draft['po_reference'];
      if (draft['pi_number'] != null) _piCtrl.text = draft['pi_number'];
      if (draft['exchange_rate'] != null) _rateCtrl.text = draft['exchange_rate'].toString();
      if (draft['notes'] != null) _notesCtrl.text = draft['notes'];
      if (draft['order_date'] != null) {
        final d = DateTime.tryParse(draft['order_date']);
        if (d != null) _selectedOrderDate = d;
      }
      if (draft['import_file_id'] != null) _selectedImportFileId = draft['import_file_id'];
      if (draft['project_id'] != null) _selectedProjectId = draft['project_id'];
      if (draft['company_id'] != null) _selectedCompanyId = draft['company_id'];
      if (draft['supplier_id'] != null) _selectedSupplierId = draft['supplier_id'];
      if (draft['incoterm_id'] != null) _selectedIncotermId = draft['incoterm_id'];
      if (draft['currency_id'] != null) _selectedCurrencyId = draft['currency_id'];
      if (draft['country_of_origin'] != null) _selectedCountryOfOrigin = draft['country_of_origin'];
      if (draft['status'] != null) _selectedStatus = draft['status'];
      if (draft['payment_terms'] != null) _selectedPaymentTerms = draft['payment_terms'];
      if (draft['pallet_count'] != null) _palletCount = (draft['pallet_count'] as num).toInt();
      if (draft['pallet_type'] != null) _selectedPalletType = draft['pallet_type'];
      if (draft['is_pallet_stackable'] != null) _isPalletStackable = draft['is_pallet_stackable'] as bool;

      if (draft['items'] is List) {
        _dialogItems = (draft['items'] as List)
            .map((i) => POLineItemModel.fromJson(Map<String, dynamic>.from(i)))
            .toList();
      }
      if (draft['packing_items'] is List) {
        _dialogPackingItems = (draft['packing_items'] as List)
            .map((p) => PackingListItemModel.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }
      _isDirty = true;
      _lastDraftSavedAt = DateTime.tryParse(draft['saved_at'] ?? '');
    });
  }

  GuideMatchResultModel? _poGuideMatchResult;

  Future<void> _loadPoGuide() async {
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final supplier = _selectedSupplierId != null
        ? suppliers.where((s) => s.supplierId == _selectedSupplierId).firstOrNull
        : null;

    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
    final incoterm = _selectedIncotermId != null
        ? incoterms.where((i) => i.incotermId == _selectedIncotermId).firstOrNull
        : null;

    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = _selectedImportFileId != null
        ? importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull
        : null;

    final firstItemHs = _dialogItems.isNotEmpty ? _dialogItems.first.hsCode : null;

    if (supplier == null && _selectedCountryOfOrigin == null && firstItemHs == null && file == null) {
      if (mounted) setState(() => _poGuideMatchResult = null);
      return;
    }

    try {
      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: supplier?.companyName,
        countryOfOrigin: _selectedCountryOfOrigin,
        incoterm: incoterm?.incotermCode,
        hsCode: firstItemHs,
        importFileReference: file?.importFileCode,
      );
      if (mounted) {
        setState(() => _poGuideMatchResult = res);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _poReferenceCtrl.removeListener(_markDirty);
    _piCtrl.removeListener(_markDirty);
    _rateCtrl.removeListener(_markDirty);
    _notesCtrl.removeListener(_markDirty);
    _poReferenceCtrl.dispose();
    _piCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final projectsAsync = ref.watch(projectsProvider);
    final companiesAsync = ref.watch(importCompaniesProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final incotermsAsync = ref.watch(incotermsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final tariffsAsync = ref.watch(customsTariffProvider);
    final importFilesAsync = ref.watch(importFilesProvider);

    final projects = projectsAsync.valueOrNull ?? [];
    final companies = companiesAsync.valueOrNull ?? [];
    final suppliers = suppliersAsync.valueOrNull ?? [];
    final incoterms = incotermsAsync.valueOrNull ?? [];
    final currencies = currenciesAsync.valueOrNull ?? [];
    final tariffs = tariffsAsync.valueOrNull ?? [];
    final importFiles = importFilesAsync.valueOrNull ?? [];

    final isArabic = context.l10n.isArabic;

    final cachedCountryItems = [
      SearchableDropdownItem<String?>(value: null, label: isArabic ? '-- الافتراضي --' : '-- Default --'),
      ...countryOptions.map((c) {
        final label = isArabic ? c['name']! : '${c['code']} - ${c['code'] == 'CN' ? 'China' : c['code'] == 'DE' ? 'Germany' : c['code'] == 'IT' ? 'Italy' : c['code'] == 'LT' ? 'Lithuania' : c['name']!.split('(').last.replaceAll(')', '')}';
        return SearchableDropdownItem<String?>(
          value: c['name'],
          label: label,
        );
      }),
    ];

    final cachedUomItems = kMasterUnitsOfMeasure.map((u) {
      final label = isArabic ? u['name']! : '${u['code']} - ${u['name']!.split(' - ').last.split('(').first.trim()}';
      return SearchableDropdownItem<String>(value: u['code']!, label: label);
    }).toList();

    final cachedPackageTypeItems = kMasterPackageTypes.map((p) {
      final cleanEn = p['name']!.split(' - ').last.split('(').first.trim();
      final label = isArabic ? '${p['name']} (${p['code']})' : '${p['code']} - $cleanEn';
      return SearchableDropdownItem<String>(value: p['name']!, label: label);
    }).toList();

    final reconciliation = evaluatePOReconciliation(
      invoiceItems: _dialogItems,
      packingItems: _dialogPackingItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHsCodes = reconciliation.items
        .where((item) => !item.isMatched || item.isMissingInPacking || item.isMissingInInvoice)
        .map((item) => item.hsCode)
        .toSet();

    final ext = widget.initialExtractedFields;
    final extTopHs = (ext != null) ? (ext['hs_code'] ?? ext['customs_tariff'] ?? ext['hsCode'])?.toString().trim() : null;

    // Reactively resolve and propagate HS codes and tariffs when provider data arrives
    if (tariffs.isNotEmpty) {
      for (int i = 0; i < _dialogItems.length; i++) {
        final item = _dialogItems[i];
        if (item.tariffId == null) {
          final targetHs = (item.hsCode != null && item.hsCode!.isNotEmpty) ? item.hsCode! : (extTopHs ?? '');
          if (targetHs.isNotEmpty) {
            final cleanHs = targetHs.replaceAll(RegExp(r'[^\d]'), '');
            final matched = tariffs.where((t) {
              final tClean = t.hsCode.replaceAll(RegExp(r'[^\d]'), '');
              return tClean == cleanHs ||
                  (cleanHs.length >= 4 && (tClean.startsWith(cleanHs) || cleanHs.startsWith(tClean))) ||
                  (cleanHs.length >= 6 && tClean.startsWith(cleanHs.substring(0, 6))) ||
                  (cleanHs.length >= 4 && tClean.startsWith(cleanHs.substring(0, 4)));
            }).firstOrNull;
            if (matched != null) {
              _dialogItems[i] = item.copyWith(tariffId: matched.tariffId, hsCode: matched.hsCode);
            } else if (item.hsCode == null || item.hsCode!.isEmpty) {
              _dialogItems[i] = item.copyWith(hsCode: targetHs);
            }
          }
        }
      }
      for (int i = 0; i < _dialogPackingItems.length; i++) {
        final p = _dialogPackingItems[i];
        if (p.hsCode.isEmpty) {
          String pHs = '';
          if (i < _dialogItems.length && _dialogItems[i].hsCode != null && _dialogItems[i].hsCode!.isNotEmpty) {
            pHs = _dialogItems[i].hsCode!;
          } else if (i < _dialogItems.length && _dialogItems[i].tariffId != null) {
            final match = tariffs.where((t) => t.tariffId == _dialogItems[i].tariffId).firstOrNull;
            if (match != null) pHs = match.hsCode;
          } else if (extTopHs != null && extTopHs.isNotEmpty) {
            pHs = extTopHs;
          }
          if (pHs.isNotEmpty) {
            _dialogPackingItems[i] = p.copyWith(hsCode: pHs);
          }
        }
        if (p.description == null || p.description!.trim().isEmpty) {
          if (i < _dialogItems.length) {
            final item = _dialogItems[i];
            final desc = item.descriptionAr.isNotEmpty ? item.descriptionAr : item.descriptionEn;
            if (desc != null && desc.isNotEmpty) {
              _dialogPackingItems[i] = _dialogPackingItems[i].copyWith(description: desc);
            }
          }
        }
      }
    }

    if (widget.po == null && ext != null) {
      _selectedCompanyId ??= _matchCompanyId(ext, companies);
      _selectedSupplierId ??= _matchSupplierId(ext, suppliers);
      _selectedIncotermId ??= _matchIncotermId(ext, incoterms);
      if (_selectedCurrencyId == null) {
        final matchedCurrId = _matchCurrencyId(ext, currencies);
        if (matchedCurrId != null) {
          _selectedCurrencyId = matchedCurrId;
          _updateExchangeRateFromCurrency(_selectedCurrencyId, currencies);
        }
      }
      if (_selectedCountryOfOrigin == null) {
        final rawCty = _getExt(ext, ['country_of_origin', 'country of origin', 'origin_country', 'supplier_country', 'supplier country', 'country'])?.toString().trim().toUpperCase();
        if (rawCty != null && rawCty.isNotEmpty) {
          _selectedCountryOfOrigin = normalizeCountryName(rawCty);
        }
      }
    }

    // When creating a NEW PO (widget.po == null): Default fallback only if not selected
    if (widget.po == null) {
      if (_selectedCompanyId == null && companies.isNotEmpty) {
        _selectedCompanyId = (ext != null ? _matchCompanyId(ext, companies) : null) ?? companies.first.companyId;
      }
      if (_selectedSupplierId == null && suppliers.isNotEmpty) {
        _selectedSupplierId = (ext != null ? _matchSupplierId(ext, suppliers) : null) ?? suppliers.first.supplierId;
      }
      if (_selectedProjectId == null && projects.isNotEmpty) {
        _selectedProjectId = projects.first.projectId;
      }
      if (_selectedIncotermId == null && incoterms.isNotEmpty) {
        final fob = incoterms.where((i) => i.incotermCode.toUpperCase().trim() == 'FOB').firstOrNull;
        _selectedIncotermId = fob?.incotermId ?? incoterms.first.incotermId;
      }
      if (_selectedCurrencyId == null && currencies.isNotEmpty) {
        final usd = currencies.where((c) => c.currencyCode.toUpperCase().trim() == 'USD').firstOrNull;
        _selectedCurrencyId = usd?.currencyId ?? currencies.first.currencyId;
        _updateExchangeRateFromCurrency(_selectedCurrencyId, currencies);
      }
    } else {
      // When editing an EXISTING PO (widget.po != null): Match and preserve existing PO codes & IDs
      final po = widget.po!;
      if (_selectedIncotermId == null || !incoterms.any((i) => i.incotermId == _selectedIncotermId)) {
        if (po.incotermId > 0 && incoterms.any((i) => i.incotermId == po.incotermId)) {
          _selectedIncotermId = po.incotermId;
        } else if (po.incotermCode != null && po.incotermCode!.isNotEmpty) {
          _selectedIncotermId = _matchIncotermId(po.incotermCode, incoterms);
        }
      }

      if (_selectedCurrencyId == null || !currencies.any((c) => c.currencyId == _selectedCurrencyId)) {
        if (po.currencyId > 0 && currencies.any((c) => c.currencyId == po.currencyId)) {
          _selectedCurrencyId = po.currencyId;
        } else if (po.currencyCode != null && po.currencyCode!.isNotEmpty) {
          _selectedCurrencyId = _matchCurrencyId(po.currencyCode, currencies);
        }
      }

      if (_selectedProjectId == null || !projects.any((p) => p.projectId == _selectedProjectId)) {
        if (po.projectId > 0 && projects.any((p) => p.projectId == po.projectId)) {
          _selectedProjectId = po.projectId;
        }
      }

      if (_selectedCompanyId == null || !companies.any((c) => c.companyId == _selectedCompanyId)) {
        if (po.companyId > 0 && companies.any((c) => c.companyId == po.companyId)) {
          _selectedCompanyId = po.companyId;
        }
      }

      if (_selectedSupplierId == null || !suppliers.any((s) => s.supplierId == _selectedSupplierId)) {
        if (po.supplierId > 0 && suppliers.any((s) => s.supplierId == po.supplierId)) {
          _selectedSupplierId = po.supplierId;
        }
      }
    }

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onDiscard: () => PODraftManager.clearDraft(widget.po?.poId),
      child: DefaultTabController(
        length: 2,
        child: AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            decoration: const BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.po == null ? context.l10n.newPurchaseOrder : '${context.l10n.editPurchaseOrder} (${widget.po!.displayName})',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_lastDraftSavedAt != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Tooltip(
                            message: 'تم حفظ المسودة محلياً في ${_lastDraftSavedAt!.hour.toString().padLeft(2, '0')}:${_lastDraftSavedAt!.minute.toString().padLeft(2, '0')}:${_lastDraftSavedAt!.second.toString().padLeft(2, '0')}',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_done_outlined, size: 14, color: AppTheme.emerald),
                                  const SizedBox(width: 4),
                                  Text(
                                    isArabic ? 'مسودة محفوظة' : 'Draft Saved',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      SmartUploadButton(
                        module: SmartUploadModule.purchaseOrder,
                        label: isArabic ? '🚀 استخلاص ذكي (PI / PL)' : '🚀 Smart Extract (PI / PL)',
                        compact: false,
                        onDataExtracted: (result) {
                          _applyExtractedData(result.extractedFields);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: context.l10n.close,
                        onPressed: () => UnsavedChangesGuard.maybePop(
                          context,
                          isDirty: _isDirty,
                          onDiscard: () => PODraftManager.clearDraft(widget.po?.poId),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  onTap: (index) {
                    if (_isDirty) {
                      _performAutosave();
                    }
                  },
                  labelColor: AppTheme.emerald,
                unselectedLabelColor: Colors.white70,
                indicatorColor: AppTheme.emerald,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.list_alt, size: 18),
                    text: '${context.l10n.poLineItemsTab} (${_dialogItems.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    text: '${context.l10n.reviewPackingListTab} (${_dialogPackingItems.length})',
                  ),
                ],
              ),
            ],
          ),

        ),
        content: SizedBox(
          width: 850,
          height: 520,
          child: Form(
            key: _formKey,
            child: TabBarView(
              children: [
                      // Tab 1: Commercial Header & Line Items
                      _KeepAliveWrapper(
                        child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.only(top: 8, end: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_poGuideMatchResult != null && _poGuideMatchResult!.matchedEntries.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExperienceGuideAlertBanner(
                                  matchResult: _poGuideMatchResult!,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_outlined, color: AppTheme.cobalt, size: 22),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🧾 أداة قراءة واستخراج الفاتورة المبدئية (Invoice Reader)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                        ),
                                        Text(
                                          'قم برفع الفاتورة المبدئية/التجارية (PDF/صورة) لاستخراج ترويسة الفاتورة، الأسعار، العملة، وبنود الشراء تلقائياً',
                                          style: TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SmartUploadButton(
                                    module: SmartUploadModule.purchaseOrder,
                                    compact: false,
                                    label: '🚀 قراءة الفاتورة المبدئية',
                                    onDataExtracted: (result) {
                                      _applyExtractedFieldsToState(result.extractedFields, targetTab: 'invoice');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تمت قراءة واستخراج بيانات الفاتورة المبدئية وبنود الشراء بنجاح!'),
                                          backgroundColor: AppTheme.emerald,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SearchableDropdownField<int?>(
                              value: _selectedImportFileId,
                              labelText: 'Import File (ملف الشحنة الاستيرادية)',
                              items: [
                                const SearchableDropdownItem<int?>(
                                  value: null,
                                  label: '-- None / غير مرتبط بملف شحنة --',
                                ),
                                ...importFiles.map((f) => SearchableDropdownItem<int?>(
                                      value: f.importFileId,
                                      label: '${f.primaryNameWithCode} - ${f.companyName}',
                                    )),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedImportFileId = v);
                                _loadPoGuide();
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _poReferenceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'PO Reference / Name (اسم / مرجع أمر الشراء)',
                                hintText: 'مثال: وحدات شيلر مصنع الدلتا / Chiller Units 500kW',
                                prefixIcon: Icon(Icons.bookmark_outline_rounded, color: AppTheme.cobalt, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _piCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Proforma Invoice # (رقم الفاتورة المبدئية)',
                                      hintText: 'e.g. PI-2026-991',
                                      prefixIcon: Icon(Icons.receipt_long_outlined, color: AppTheme.cobalt, size: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedOrderDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _selectedOrderDate = picked;
                                          _updateExchangeRateFromCurrency(_selectedCurrencyId, currencies);
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Invoice Date (تاريخ الفاتورة) *',
                                        prefixIcon: Icon(Icons.calendar_today, color: AppTheme.cobalt),
                                      ),
                                      child: Text(
                                        '${_selectedOrderDate.year}-${_selectedOrderDate.month.toString().padLeft(2, '0')}-${_selectedOrderDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<int?>(
                                    value: _selectedProjectId,
                                    labelText: 'Project *',
                                    items: projects
                                        .map((p) => SearchableDropdownItem<int?>(
                                              value: p.projectId,
                                              label: '${p.projectCode} (${p.projectName})',
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedProjectId = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SearchableDropdownField<int?>(
                                        value: _selectedCompanyId,
                                        labelText: 'Importing Company (الشركة المستوردة) *',
                                        items: companies
                                            .map((c) => SearchableDropdownItem<int?>(
                                                  value: c.companyId,
                                                  label: c.importerName,
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedCompanyId = v);
                                        },
                                      ),
                                      const SizedBox(height: 3),
                                      InkWell(
                                        onTap: () => UniversalEntityExtractorDialog.show(
                                          context,
                                          initialTarget: EntityTarget.company,
                                          onSaved: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.domain_add, size: 13, color: AppTheme.cobalt),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '+ استدعاء AI Extractor & Coding لتكويد شركة مستوردة',
                                                  style: TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SearchableDropdownField<int?>(
                                        value: _selectedSupplierId,
                                        labelText: 'Supplier (المورد الأجنبي) *',
                                        items: suppliers
                                            .map((s) => SearchableDropdownItem<int?>(
                                                  value: s.supplierId,
                                                  label: s.companyName,
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _selectedSupplierId = v);
                                            _loadPoGuide();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 3),
                                      InkWell(
                                        onTap: () => UniversalEntityExtractorDialog.show(
                                          context,
                                          initialTarget: EntityTarget.supplier,
                                          onSaved: () => ref.read(suppliersProvider.notifier).fetchSuppliers(),
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.auto_awesome, size: 13, color: AppTheme.cobalt),
                                              SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '+ استدعاء AI Extractor & Coding لتكويد مورد جديد',
                                                  style: TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: SearchableDropdownField<int?>(
                                    key: ValueKey('incoterm_dropdown_${_selectedIncotermId}_${incoterms.length}'),
                                    value: _selectedIncotermId,
                                    labelText: 'Incoterm *',
                                    items: incoterms
                                        .map((i) => SearchableDropdownItem<int?>(
                                              value: i.incotermId,
                                              label: '${i.incotermCode} (${i.incotermName})',
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedIncotermId = v);
                                        _loadPoGuide();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<int?>(
                                    key: ValueKey('currency_dropdown_${_selectedCurrencyId}_${currencies.length}'),
                                    value: _selectedCurrencyId,
                                    labelText: 'Currency *',
                                    items: currencies
                                        .map((c) => SearchableDropdownItem<int?>(
                                              value: c.currencyId,
                                              label: '${c.currencyCode} (${c.currencyName})',
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _selectedCurrencyId = v;
                                          _updateExchangeRateFromCurrency(v, currencies);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: SearchableDropdownField<String?>(
                                    value: _selectedCountryOfOrigin,
                                    labelText: 'Country of Origin (بلد المنشأ العام)',
                                    items: [
                                      const SearchableDropdownItem<String?>(
                                        value: null,
                                        label: '-- غير محدد (Auto / غير محدد) --',
                                      ),
                                      ...countryOptions.map((c) => SearchableDropdownItem<String?>(
                                            value: c['name'],
                                            label: c['name']!,
                                          )),
                                    ],
                                    onChanged: (v) {
                                      setState(() => _selectedCountryOfOrigin = v);
                                      _loadPoGuide();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: _selectedStatus,
                                    labelText: 'Status',
                                    items: ['Draft', 'Approved', 'In Transit', 'Closed', 'Cancelled']
                                        .map((s) => SearchableDropdownItem<String>(value: s, label: s))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedStatus = v ?? 'Draft'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _rateCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Exchange Rate (سعر الصرف)',
                                      helperText: '⚡ يستدعى آلياً حسب تاريخ الفاتورة والعملة',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SearchableDropdownField<String>(
                                    value: ['Cash in Advance / SWIFT', 'Letter of Credit / LC', 'CAD / Cash Against Documents', 'Open Account / Deferred Payment'].contains(_selectedPaymentTerms)
                                        ? _selectedPaymentTerms
                                        : 'Cash in Advance / SWIFT',
                                    labelText: 'Payment Terms (شروط الدفع) *',
                                    items: const [
                                      SearchableDropdownItem(
                                        value: 'Cash in Advance / SWIFT',
                                        label: 'Cash in Advance / SWIFT (تحويل سويفت مقدم)',
                                      ),
                                      SearchableDropdownItem(
                                        value: 'Letter of Credit / LC',
                                        label: 'Letter of Credit / LC (اعتماد مستندي)',
                                      ),
                                      SearchableDropdownItem(
                                        value: 'CAD / Cash Against Documents',
                                        label: 'CAD / Cash Against Documents (تحصيل مستندي)',
                                      ),
                                      SearchableDropdownItem(
                                        value: 'Open Account / Deferred Payment',
                                        label: 'Open Account / Deferred Payment (حساب مفتوح / آجل)',
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedPaymentTerms = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Line Items Header & Add Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'PO Line Items (بنود الفاتورة المبدئية) *',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Item'),
                                  onPressed: () {
                                    setState(() {
                                      _dialogItems.add(
                                        POLineItemModel(
                                          descriptionAr: 'بند جديد ${_dialogItems.length + 1}',
                                          quantity: 1,
                                          unitPrice: 0,
                                          countryOfOrigin: _selectedCountryOfOrigin,
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dynamic Line Items List
                            ..._dialogItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final itemHs = item.hsCode ?? (item.tariffId != null && tariffs.any((t) => t.tariffId == item.tariffId) ? tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsCode : '');
                              final isMismatched = itemHs.isNotEmpty && mismatchedHsCodes.contains(itemHs);

                              return Card(
                                key: ValueKey('po_line_item_card_${identityHashCode(item)}'),
                                color: isMismatched ? Colors.red.shade50.withOpacity(0.4) : Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isMismatched ? Colors.red.shade300 : Colors.grey.shade300,
                                    width: isMismatched ? 1.5 : 1.0,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('#${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              key: ValueKey('po_item_code_${identityHashCode(item)}'),
                                              initialValue: item.itemCode,
                                              decoration: const InputDecoration(labelText: 'Item Code (كود البند)', isDense: true),
                                              onChanged: (v) => _dialogItems[idx] = _dialogItems[idx].copyWith(itemCode: v.trim().isEmpty ? null : v.trim()),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              key: ValueKey('po_item_main_desc_${identityHashCode(item)}'),
                                              initialValue: item.mainDescription,
                                              decoration: const InputDecoration(labelText: 'Main Description (الوصف الرئيسي)', isDense: true),
                                              onChanged: (v) => _dialogItems[idx] = _dialogItems[idx].copyWith(mainDescription: v.trim().isEmpty ? null : v.trim()),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                              key: ValueKey('po_item_desc_${identityHashCode(item)}'),
                                              initialValue: item.descriptionAr,
                                              decoration: const InputDecoration(labelText: 'Arabic Description *', isDense: true),
                                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                              onChanged: (v) => _dialogItems[idx] = _dialogItems[idx].copyWith(descriptionAr: v),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: InkWell(
                                              onTap: () async {
                                                final picked = await _showHsCodeSearchPicker(context, tariffs);
                                                setState(() {
                                                  _dialogItems[idx] = _dialogItems[idx].copyWith(
                                                    tariffId: picked?.tariffId,
                                                    hsCode: picked?.hsCode,
                                                  );
                                                });
                                              },
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  labelText: 'Customs Tariff / HS Code (بحث 🔍)',
                                                  isDense: true,
                                                  suffixIcon: isMismatched ? const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16) : null,
                                                ),
                                                child: Text(
                                                  item.tariffId != null
                                                      ? (tariffs.any((t) => t.tariffId == item.tariffId)
                                                          ? '${tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsCode} - ${tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsDescription}'
                                                          : (item.hsCode ?? 'ID #${item.tariffId}'))
                                                      : (item.hsCode != null && item.hsCode!.isNotEmpty ? item.hsCode! : 'None / General'),
                                                  style: TextStyle(
                                                    fontWeight: (item.tariffId != null || (item.hsCode != null && item.hsCode!.isNotEmpty)) ? FontWeight.bold : FontWeight.normal,
                                                    color: isMismatched ? Colors.red.shade900 : ((item.tariffId != null || (item.hsCode != null && item.hsCode!.isNotEmpty)) ? AppTheme.cobalt : Colors.grey.shade700),
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: SearchableDropdownField<String?>(
                                              value: normalizeCountryName(item.countryOfOrigin ?? _selectedCountryOfOrigin),
                                              labelText: 'بلد المنشأ للبند',
                                              searchHintText: 'ابحث عن بلد المنشأ...',
                                              items: cachedCountryItems,
                                              onChanged: (v) {
                                                setState(() {
                                                  _dialogItems[idx] = _dialogItems[idx].copyWith(countryOfOrigin: normalizeCountryName(v));
                                                });
                                              },
                                            ),
                                          ),
                                           IconButton(
                                             icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                                             tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'تكرار / استنساخ البند (Ctrl + D)' : 'Clone Line Item (Ctrl + D)',
                                             onPressed: () => _cloneLineItem(idx),
                                           ),
                                          if (_dialogItems.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                                              onPressed: () => setState(() => _dialogItems.removeAt(idx)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextFormField(
                                               key: ValueKey('po_item_qty_${identityHashCode(item)}'),
                                              initialValue: item.quantity.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(labelText: 'Qty (الكمية/العدد)', isDense: true),
                                              onChanged: (v) {
                                                final q = double.tryParse(v) ?? 1.0;
                                                setState(() {
                                                  _dialogItems[idx] = _dialogItems[idx].copyWith(quantity: q, totalPrice: q * _dialogItems[idx].unitPrice);
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: SearchableDropdownField<String>(
                                              value: item.unitOfMeasure,
                                              labelText: 'Unit / الوحدة',
                                              items: cachedUomItems,
                                              onChanged: (v) {
                                                if (v != null) {
                                                  setState(() {
                                                    _dialogItems[idx] = _dialogItems[idx].copyWith(unitOfMeasure: v);
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                               key: ValueKey('po_item_price_${identityHashCode(item)}'),
                                              initialValue: item.unitPrice.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(labelText: 'Unit Price (سعر الوحده)', isDense: true),
                                              onChanged: (v) {
                                                final p = double.tryParse(v) ?? 0.0;
                                                setState(() {
                                                  _dialogItems[idx] = _dialogItems[idx].copyWith(unitPrice: p);
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                             decoration: BoxDecoration(
                                               color: Colors.green.shade50,
                                               borderRadius: BorderRadius.circular(6),
                                               border: Border.all(color: Colors.green.shade300),
                                             ),
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.center,
                                               children: [
                                                 const Text('Line Total (إجمالي السطر)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                                 Text(
                                                   '${currencies.firstWhere((c) => c.currencyId == _selectedCurrencyId, orElse: () => CurrencyModel(currencyId: 0, currencyCode: "USD", currencyName: "USD", currencySymbol: "\$")).currencyCode} ${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                                                   style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ],
                                       ),

                                       // Unregistered HS Code Warning Banner per Item with Smart Nafeza Trigger
                                       if (item.tariffId == null || !tariffs.any((t) => t.tariffId == item.tariffId))
                                         Container(
                                           margin: const EdgeInsets.only(top: 8),
                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                           decoration: BoxDecoration(
                                             color: Colors.amber.shade50,
                                             borderRadius: BorderRadius.circular(8),
                                             border: Border.all(color: Colors.amber.shade400, width: 1.2),
                                           ),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Row(
                                                 children: [
                                                   Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 18),
                                                   const SizedBox(width: 6),
                                                   Expanded(
                                                     child: Text(
                                                       '⚠️ بند التعريفة الجمركية (${item.hsCode ?? "غير مسجل"}) غير مسجل في جدول التعريفة المعتمد — يرجى تسجيله عبر Smart Nafeza لتطبيق الرسوم الجمركية وضريبة الوارد بدقة.',
                                                       style: TextStyle(
                                                         color: Colors.amber.shade900,
                                                         fontSize: 11,
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               const SizedBox(height: 6),
                                               Wrap(
                                                 spacing: 8,
                                                 runSpacing: 4,
                                                 children: [
                                                   ElevatedButton.icon(
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: AppTheme.orange,
                                                       foregroundColor: Colors.white,
                                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                       visualDensity: VisualDensity.compact,
                                                     ),
                                                     icon: const Icon(Icons.auto_fix_high, size: 14),
                                                     label: const Text('✨ استدعاء Smart Nafeza & Diff Engine لتسجيل البند', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                     onPressed: () => showTariffDialog(context, ref, initialModeIndex: 0),
                                                   ),
                                                   OutlinedButton.icon(
                                                     style: OutlinedButton.styleFrom(
                                                       foregroundColor: AppTheme.cobalt,
                                                       side: const BorderSide(color: AppTheme.cobalt),
                                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                       visualDensity: VisualDensity.compact,
                                                     ),
                                                     icon: const Icon(Icons.search, size: 14),
                                                     label: const Text('🔍 بحث واختيار من التعريفة', style: TextStyle(fontSize: 11)),
                                                     onPressed: () async {
                                                       final picked = await _showHsCodeSearchPicker(context, tariffs);
                                                       if (picked != null) {
                                                         setState(() {
                                                           _dialogItems[idx] = _dialogItems[idx].copyWith(
                                                             tariffId: picked.tariffId,
                                                             hsCode: picked.hsCode,
                                                           );
                                                         });
                                                       }
                                                     },
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                     ],
                                   ),
                                 ),
                               );
                             }),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'PO Notes & Instructions'),
                            ),
                          ],
                        ),
                        ),
                      ),

                      // Tab 2: BP-003 Dynamic Detailed Packing List
                      _KeepAliveWrapper(
                        child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.only(top: 8, end: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, color: AppTheme.emerald, size: 22),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📦 أداة قراءة واستخراج بيان التعبئة والوزن (Packing List Reader)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                        ),
                                        Text(
                                          'قم برفع ملف بيان التعبئة (Packing List PDF/صورة) لاستخراج أعداد الطرود، الأوزان القائمة والصافية، والأحجام CBM تلقائياً',
                                          style: TextStyle(fontSize: 11, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SmartUploadButton(
                                    module: SmartUploadModule.purchaseOrder,
                                    compact: false,
                                    label: '🚀 قراءة بيان التعبئة',
                                    onDataExtracted: (result) {
                                      _applyExtractedFieldsToState(result.extractedFields, targetTab: 'packing');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تمت قراءة واستخراج بيانات كشف التعبئة والوزن (Packing List) بنجاح!'),
                                          backgroundColor: AppTheme.emerald,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Dual-Mode Selection Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tune_rounded, color: AppTheme.charcoal, size: 20),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'مسار إدخال ومعالجة الشحنة:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                  ),
                                  const SizedBox(width: 12),
                                  ChoiceChip(
                                    label: const Text('📏 مسار الأبعاد الصريحة (L × W × H)'),
                                    selected: !_isDirectVolumeMode,
                                    onSelected: (val) {
                                      if (val) setState(() => _isDirectVolumeMode = false);
                                    },
                                    selectedColor: AppTheme.cobalt.withOpacity(0.18),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('📦 مسار الحجم المباشر CBM ومخطط البالتات'),
                                    selected: _isDirectVolumeMode,
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _isDirectVolumeMode = true;
                                          if (_dialogPalletItems.isEmpty) {
                                            _dialogPalletItems.add(PalletPlanItemModel(
                                              palletType: 'Euro Pallet (120x80)',
                                              palletCount: 1,
                                              lengthCm: 120.0,
                                              widthCm: 80.0,
                                              heightCm: 150.0,
                                              grossWeightPerPalletKg: 0.0,
                                              isStackable: false,
                                            ));
                                          }
                                        });
                                      }
                                    },
                                    selectedColor: AppTheme.emerald.withOpacity(0.18),
                                  ),
                                ],
                              ),
                            ),

                            // Multi-Row Palletization Board (Visible when Direct Volume Mode is active)
                            if (_isDirectVolumeMode)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Responsive Header
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      alignment: WrapAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.pallet, color: AppTheme.cobalt, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              context.l10n.masterPalletizationPlanTitle,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cobalt.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                '🔢 ${context.l10n.totalPalletsPill(_dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount))}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.orange.withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                '📐 ${context.l10n.palletsVolumePill(_dialogPalletItems.fold<double>(0.0, (sum, p) => sum + p.calculatedCbm).toStringAsFixed(3))}',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.cobalt,
                                                side: const BorderSide(color: AppTheme.cobalt),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              ),
                                              icon: const Icon(Icons.add_circle_outline, size: 16),
                                              label: Text(context.l10n.addPalletRowBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () {
                                                setState(() {
                                                  _dialogPalletItems.add(PalletPlanItemModel(
                                                    palletType: 'Euro Pallet (120x80)',
                                                    palletCount: 1,
                                                    lengthCm: 120.0,
                                                    widthCm: 80.0,
                                                    heightCm: 150.0,
                                                    grossWeightPerPalletKg: 0.0,
                                                    isStackable: false,
                                                  ));
                                                });
                                              },
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                                              label: Text(context.l10n.simulateAndPackPallets3dBtn(_dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () => _showPoVisualLoadPlannerDialog(context, _dialogPackingItems),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    const SizedBox(height: 10),

                                    // Multi-Line Pallet List
                                    if (_dialogPalletItems.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: TextButton.icon(
                                            icon: const Icon(Icons.add, color: AppTheme.cobalt),
                                            label: Text(context.l10n.clickToAddPalletsPrompt),
                                            onPressed: () {
                                              setState(() {
                                                _dialogPalletItems.add(PalletPlanItemModel(
                                                  palletType: 'Euro Pallet (120x80)',
                                                  palletCount: 1,
                                                  lengthCm: 120.0,
                                                  widthCm: 80.0,
                                                  heightCm: 150.0,
                                                  grossWeightPerPalletKg: 0.0,
                                                  isStackable: false,
                                                ));
                                              });
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      ..._dialogPalletItems.asMap().entries.map((entry) {
                                        final pIdx = entry.key;
                                        final pLine = entry.value;

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.cobalt.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        context.l10n.palletRowHeader(pIdx + 1),
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: pLine.isStackable ? Colors.green.shade50 : Colors.orange.shade50,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: pLine.isStackable ? Colors.green.shade300 : Colors.orange.shade300),
                                                      ),
                                                      child: Text(
                                                        pLine.isStackable ? context.l10n.palletStackableBadge : context.l10n.palletFloorOnlyBadge,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: pLine.isStackable ? Colors.green.shade900 : Colors.orange.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      context.l10n.palletRowSummary(pLine.calculatedCbm.toStringAsFixed(3), pLine.totalWeightKg.toStringAsFixed(1)),
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: context.l10n.deletePalletRowTooltip,
                                                      onPressed: () {
                                                        setState(() {
                                                          _dialogPalletItems.removeAt(pIdx);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: SearchableDropdownField<String>(
                                                        value: pLine.palletType,
                                                        labelText: context.l10n.palletTypeAndSizeLabel,
                                                        items: [
                                                          const SearchableDropdownItem(value: 'Euro Pallet (120x80)', label: 'Euro Pallet (120 × 80 cm)'),
                                                          const SearchableDropdownItem(value: 'Standard Pallet (120x100)', label: 'Standard Industrial (120 × 100 cm)'),
                                                          SearchableDropdownItem(value: 'Custom Pallet', label: context.l10n.customPalletOption),
                                                        ],
                                                        onChanged: (v) {
                                                          if (v != null) {
                                                            setState(() {
                                                              double newL = pLine.lengthCm;
                                                              double newW = pLine.widthCm;
                                                              if (v.contains('120x80')) {
                                                                newL = 120.0;
                                                                newW = 80.0;
                                                              } else if (v.contains('120x100')) {
                                                                newL = 120.0;
                                                                newW = 100.0;
                                                              }
                                                              _dialogPalletItems[pIdx] = pLine.copyWith(
                                                                palletType: v,
                                                                lengthCm: newL,
                                                                widthCm: newW,
                                                              );
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextFormField(
                                                        initialValue: pLine.palletCount.toString(),
                                                        keyboardType: TextInputType.number,
                                                        decoration: InputDecoration(labelText: context.l10n.palletCountFieldLabel, isDense: true),
                                                        onChanged: (v) {
                                                          final count = int.tryParse(v) ?? 1;
                                                          setState(() {
                                                            _dialogPalletItems[pIdx] = pLine.copyWith(palletCount: count > 0 ? count : 1);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 3,
                                                      child: SearchableDropdownField<bool>(
                                                        value: pLine.isStackable,
                                                        labelText: context.l10n.palletStackingInstructionsLabel,
                                                        items: [
                                                          SearchableDropdownItem(value: false, label: '🚫 ${context.l10n.simulationModeFloorOnly}'),
                                                          SearchableDropdownItem(value: true, label: '📦 ${context.l10n.simulationModeStackable}'),
                                                        ],
                                                        onChanged: (v) {
                                                          if (v != null) {
                                                            setState(() {
                                                              _dialogPalletItems[pIdx] = pLine.copyWith(isStackable: v);
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextFormField(
                                                        initialValue: pLine.lengthCm.toString(),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(labelText: 'Length (cm)', isDense: true),
                                                        onChanged: (v) {
                                                          final val = double.tryParse(v) ?? 120.0;
                                                          setState(() {
                                                            _dialogPalletItems[pIdx] = pLine.copyWith(lengthCm: val);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: TextFormField(
                                                        initialValue: pLine.widthCm.toString(),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(labelText: 'Width (cm)', isDense: true),
                                                        onChanged: (v) {
                                                          final val = double.tryParse(v) ?? 80.0;
                                                          setState(() {
                                                            _dialogPalletItems[pIdx] = pLine.copyWith(widthCm: val);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: TextFormField(
                                                        initialValue: pLine.heightCm.toString(),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(labelText: 'Height (cm)', isDense: true),
                                                        onChanged: (v) {
                                                          final val = double.tryParse(v) ?? 150.0;
                                                          setState(() {
                                                            _dialogPalletItems[pIdx] = pLine.copyWith(heightCm: val);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: TextFormField(
                                                        initialValue: pLine.grossWeightPerPalletKg.toString(),
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: const InputDecoration(labelText: 'وزن البالتة Gross (kg)', isDense: true),
                                                        onChanged: (v) {
                                                          final val = double.tryParse(v) ?? 500.0;
                                                          setState(() {
                                                            _dialogPalletItems[pIdx] = pLine.copyWith(grossWeightPerPalletKg: val);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l.packingListEntriesSection,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                ),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
                                      icon: const Icon(Icons.auto_fix_high, size: 16),
                                      label: Text(l.autoFillFromInvoice, style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        if (_dialogItems.isEmpty) return;
                                        setState(() {
                                          _dialogPackingItems.clear();
                                          for (int i = 0; i < _dialogItems.length; i++) {
                                            final item = _dialogItems[i];
                                            String itemHsCode = '';
                                            if (item.hsCode != null && item.hsCode!.isNotEmpty) {
                                              itemHsCode = item.hsCode!;
                                            } else if (item.tariffId != null) {
                                              final matchingTariff = tariffs.cast<CustomsTariffModel?>().firstWhere(
                                                    (t) => t?.tariffId == item.tariffId,
                                                    orElse: () => null,
                                                  );
                                              if (matchingTariff != null && matchingTariff.hsCode.isNotEmpty) {
                                                itemHsCode = matchingTariff.hsCode;
                                              }
                                            }
                                            _dialogPackingItems.add(
                                              PackingListItemModel(
                                                hsCode: itemHsCode,
                                                itemCode: (item.itemCode != null && item.itemCode!.trim().isNotEmpty)
                                                    ? item.itemCode!.trim()
                                                    : 'ITEM-${(i + 1).toString().padLeft(3, '0')}',
                                                mainDescription: item.mainDescription,
                                                description: item.descriptionAr.isNotEmpty ? item.descriptionAr : item.descriptionEn,
                                                qtyPcs: item.quantity > 0 ? item.quantity : 100.0,
                                                qtyPkg: (item.quantity > 0 ? (item.quantity / 10).ceilToDouble() : 10.0),
                                                packageType: 'Carton',
                                                lengthCm: 50.0,
                                                widthCm: 40.0,
                                                heightCm: 30.0,
                                                netWeightUnitKg: item.netWeightKg > 0 ? item.netWeightKg : 5.0,
                                                grossWeightUnitKg: item.grossWeightKg > 0 ? item.grossWeightKg : 6.0,
                                              ),
                                            );
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(l.autoFillSuccessNotice(_dialogPackingItems.length)),
                                            backgroundColor: AppTheme.emerald,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.cobalt,
                                        side: const BorderSide(color: AppTheme.cobalt),
                                      ),
                                      icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                                      label: Text(l.simulateAndPack3d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showPoVisualLoadPlannerDialog(context, _dialogPackingItems),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.playlist_add, size: 18, color: AppTheme.cobalt),
                                      label: Text(l.addPackingEntryBtn, style: const TextStyle(color: AppTheme.cobalt)),
                                      onPressed: () {
                                        String defaultHs = '';
                                        String? defaultMainDesc;
                                        String? defaultDesc;
                                        if (_dialogItems.isNotEmpty) {
                                          final first = _dialogItems.first;
                                          if (first.hsCode != null && first.hsCode!.isNotEmpty) {
                                            defaultHs = first.hsCode!;
                                          } else if (first.tariffId != null) {
                                            final match = tariffs.cast<CustomsTariffModel?>().firstWhere((t) => t?.tariffId == first.tariffId, orElse: () => null);
                                            if (match != null) defaultHs = match.hsCode;
                                          }
                                          defaultMainDesc = first.mainDescription;
                                          defaultDesc = first.descriptionAr.isNotEmpty ? first.descriptionAr : first.descriptionEn;
                                        }
                                        setState(() {
                                          _dialogPackingItems.add(
                                            PackingListItemModel(
                                              hsCode: defaultHs,
                                              itemCode: 'ITEM-${(_dialogPackingItems.length + 1).toString().padLeft(3, "0")}',
                                              mainDescription: defaultMainDesc,
                                              description: defaultDesc,
                                              qtyPcs: 10,
                                              qtyPkg: 1,
                                              packageType: 'Carton',
                                              lengthCm: 50,
                                              widthCm: 40,
                                              heightCm: 30,
                                              netWeightUnitKg: 5,
                                              grossWeightUnitKg: 6,
                                            ),
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            _dialogPackingItems.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            l.noPackingEntriesYet,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            l.noPackingEntriesYetDesc,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _dialogPackingItems.length,
                                    itemBuilder: (context, idx) {
                                          final p = _dialogPackingItems[idx];
                                          final isMismatched = p.hsCode.isNotEmpty && mismatchedHsCodes.contains(p.hsCode);

                                          return Card(
                                             key: ValueKey('po_pkg_card_${identityHashCode(p)}'),
                                            color: isMismatched ? Colors.red.shade50.withOpacity(0.4) : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: isMismatched ? Colors.red.shade400 : Colors.blue.shade200,
                                                width: isMismatched ? 1.5 : 1.0,
                                              ),
                                            ),
                                            margin: const EdgeInsets.only(bottom: 10),
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                       Container(
                                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                         decoration: BoxDecoration(
                                                           color: isMismatched ? Colors.red.withOpacity(0.15) : AppTheme.cobalt.withOpacity(0.15),
                                                           borderRadius: BorderRadius.circular(4),
                                                         ),
                                                         child: Text(
                                                           l.pkgCardNumber(idx + 1),
                                                           style: TextStyle(
                                                             fontWeight: FontWeight.bold,
                                                             color: isMismatched ? Colors.red.shade900 : AppTheme.cobalt,
                                                             fontSize: 12,
                                                           ),
                                                         ),
                                                       ),
                                                       const SizedBox(width: 8),
                                                       Expanded(
                                                         flex: 3,
                                                         child: InkWell(
                                                           onTap: () async {
                                                             final picked = await _showHsCodeSearchPicker(context, tariffs);
                                                             if (picked != null) {
                                                               setState(() {
                                                                 _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(hsCode: picked.hsCode);
                                                               });
                                                             }
                                                           },
                                                           child: InputDecorator(
                                                             decoration: InputDecoration(
                                                               labelText: l.hsCodeSearchFieldLabel,
                                                               isDense: true,
                                                               suffixIcon: isMismatched ? const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16) : null,
                                                             ),
                                                             child: Text(
                                                               p.hsCode.isNotEmpty ? p.hsCode : l.selectTariffItemHint,
                                                               style: TextStyle(
                                                                 fontWeight: p.hsCode.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                                                 color: isMismatched ? Colors.red.shade900 : (p.hsCode.isNotEmpty ? AppTheme.cobalt : Colors.grey.shade600),
                                                                 fontSize: 12,
                                                               ),
                                                               overflow: TextOverflow.ellipsis,
                                                             ),
                                                           ),
                                                         ),
                                                       ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextFormField(
                                                       key: ValueKey('po_pkg_code_${identityHashCode(p)}'),
                                                      initialValue: p.itemCode,
                                                      decoration: InputDecoration(labelText: l.itemCodeLabel, isDense: true),
                                                      validator: (v) => v == null || v.trim().isEmpty ? context.l10n.fieldRequired : null,
                                                      onChanged: (v) {
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(itemCode: v.trim());
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: TextFormField(
                                                       key: ValueKey('po_pkg_main_desc_${identityHashCode(p)}'),
                                                      initialValue: p.mainDescription ?? '',
                                                      decoration: InputDecoration(
                                                        labelText: '${l.mainDescription} (الوصف الرئيسي)',
                                                        isDense: true,
                                                      ),
                                                      onChanged: (v) {
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(
                                                          mainDescription: v.trim().isNotEmpty ? v.trim() : null,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: TextFormField(
                                                       key: ValueKey('po_pkg_desc_${identityHashCode(p)}'),
                                                      initialValue: p.description ?? '',
                                                      decoration: InputDecoration(
                                                        labelText: l.itemDescriptionLabel,
                                                        hintText: l.itemNameOrDescHint,
                                                        isDense: true,
                                                      ),
                                                      onChanged: (v) {
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(
                                                          description: v.trim().isNotEmpty ? v.trim() : null,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: SearchableDropdownField<String>(
                                                      value: p.packageType,
                                                      labelText: l.packageTypeFieldLabel,
                                                      items: cachedPackageTypeItems,
                                                      onChanged: (v) => setState(() {
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(packageType: v ?? 'CT');
                                                      }),
                                                    ),
                                                  ),
                                                   IconButton(
                                                     icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                                                     tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'استنساخ الطرد' : 'Clone Package',
                                                     onPressed: () => _clonePackingItem(idx),
                                                   ),
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                                                    onPressed: () => setState(() => _dialogPackingItems.removeAt(idx)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 100,
                                                    child: SearchableDropdownField<String>(
                                                      value: p.unit,
                                                      labelText: l.unitFieldLabel,
                                                      items: const [
                                                        SearchableDropdownItem(value: 'cm', label: 'cm'),
                                                        SearchableDropdownItem(value: 'mm', label: 'mm'),
                                                        SearchableDropdownItem(value: 'm', label: 'm'),
                                                      ],
                                                      onChanged: (v) => setState(() {
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(unit: v ?? 'cm');
                                                      }),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_qty_pcs_${identityHashCode(p)}'),
                                                      initialValue: p.qtyPcs.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(labelText: l.qtyPcsFieldLabel, isDense: true),
                                                      onChanged: (v) {
                                                        final q = double.tryParse(v) ?? 1.0;
                                                        _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(qtyPcs: q);
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_qty_pkg_${identityHashCode(p)}'),
                                                      initialValue: p.qtyPkg.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(labelText: l.qtyPkgFieldLabel, isDense: true),
                                                      onChanged: (v) {
                                                        final q = double.tryParse(v) ?? 1.0;
                                                        setState(() {
                                                          _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(qtyPkg: q);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_len_${identityHashCode(p)}'),
                                                      initialValue: p.lengthCm.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(labelText: l.lengthFieldLabel(p.unit), isDense: true),
                                                      onChanged: (v) {
                                                        final len = double.tryParse(v) ?? 0.0;
                                                        setState(() {
                                                          _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(lengthCm: len);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_width_${identityHashCode(p)}'),
                                                      initialValue: p.widthCm.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(labelText: l.widthFieldLabel(p.unit), isDense: true),
                                                      onChanged: (v) {
                                                        final w = double.tryParse(v) ?? 0.0;
                                                        setState(() {
                                                          _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(widthCm: w);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_height_${identityHashCode(p)}'),
                                                      initialValue: p.heightCm.toString(),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: InputDecoration(labelText: l.heightFieldLabel(p.unit), isDense: true),
                                                      onChanged: (v) {
                                                        final h = double.tryParse(v) ?? 0.0;
                                                        setState(() {
                                                          _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(heightCm: h);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                               Row(
                                                 children: [
                                                   Expanded(
                                                     flex: 3,
                                                     child: SearchableDropdownField<String>(
                                                       value: p.weightUnit,
                                                       labelText: l.weightUnitFieldLabel,
                                                       items: cachedUomItems,
                                                       onChanged: (v) {
                                                         if (v != null) {
                                                           setState(() {
                                                             _dialogPackingItems[idx] = p.copyWith(weightUnit: v);
                                                           });
                                                         }
                                                       },
                                                     ),
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Expanded(
                                                     flex: 2,
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_net_wt_${identityHashCode(p)}'),
                                                       initialValue: _formatDecimalInput(p.netWeightUnitKg),
                                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                       decoration: InputDecoration(labelText: l.netWeightFieldLabel(p.weightUnit), isDense: true),
                                                       onChanged: (v) {
                                                         final nw = double.tryParse(v) ?? 0.0;
                                                         setState(() {
                                                           _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(netWeightUnitKg: nw);
                                                         });
                                                       },
                                                     ),
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Expanded(
                                                     flex: 2,
                                                     child: TextFormField(
                                                       key: ValueKey('po_pkg_gross_wt_${identityHashCode(p)}'),
                                                       initialValue: _formatDecimalInput(p.grossWeightUnitKg),
                                                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                       decoration: InputDecoration(labelText: l.grossWeightFieldLabel(p.weightUnit), isDense: true),
                                                       onChanged: (v) {
                                                         final gw = double.tryParse(v) ?? 0.0;
                                                         setState(() {
                                                           _dialogPackingItems[idx] = _dialogPackingItems[idx].copyWith(grossWeightUnitKg: gw);
                                                         });
                                                       },
                                                     ),
                                                   ),
                                                   const SizedBox(width: 8),
                                                   Expanded(
                                                     flex: 3,
                                                     child: SearchableDropdownField<bool>(
                                                       value: p.isStackable,
                                                       labelText: l.stackingInstructionsLabel,
                                                       items: [
                                                         SearchableDropdownItem(value: true, label: l.stackableOption),
                                                         SearchableDropdownItem(value: false, label: l.nonStackableOption),
                                                       ],
                                                       onChanged: (v) => setState(() {
                                                         _dialogPackingItems[idx] = p.copyWith(isStackable: v ?? true);
                                                       }),
                                                     ),
                                                   ),
                                                   const SizedBox(width: 10),
                                                   Expanded(
                                                     flex: 4,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment: Alignment.center,
                                                        child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: [
                                                          Column(
                                                            children: [
                                                              Text(l.totalVolumePill, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                              Text('${p.calculatedCbm.toStringAsFixed(4)} m³', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                                                            ],
                                                          ),
                                                          Column(
                                                            children: [
                                                              Text(l.totalGrossWeightPill, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                              Text('${_formatDecimalInput(p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg))} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt)),
                                                            ],
                                                          ),
                                                          Column(
                                                            children: [
                                                              Text(l.airChargeablePill, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                              Text('${_formatDecimalInput(p.calculatedCbm * 166.67)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                                                            ],
                                                          ),
                                                        ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        actions: [
          TextButton(
            onPressed: () => UnsavedChangesGuard.maybePop(
              context,
              isDirty: _isDirty,
              onDiscard: () => PODraftManager.clearDraft(widget.po?.poId),
            ),
            child: Text(context.l10n.cancel),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              side: const BorderSide(color: AppTheme.cobalt, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.preview_rounded, size: 18),
            label: Text(context.l10n.previewPoReportBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showPoComprehensiveReportPreview(context),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              widget.po == null ? context.l10n.savePurchaseOrderBtn : context.l10n.savePoEditsBtn,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _isSubmitting ? null : () => _submitForm(context),
          ),
        ],
      ),
    ),
  );
  }

  Future<void> _submitForm(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء استكمال الحقول الإلزامية (الوصف العربي، HS Code، كود البند) بجميع التبويبات.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedProjectId == null ||
        _selectedCompanyId == null ||
        _selectedSupplierId == null ||
        _selectedIncotermId == null ||
        _selectedCurrencyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء التأكد من اختيار كافة الحقول الإلزامية (المشروع، الشركة المستوردة، المورد، الـ Incoterm والعملة).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dialogItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إضافة بند استيرادي واحد على الأقل في أمر الشراء.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final tariffs = ref.read(customsTariffProvider).value ?? [];
    final reconciliation = evaluatePOReconciliation(
      invoiceItems: _dialogItems,
      packingItems: _dialogPackingItems,
      tariffs: tariffs,
    );

    String? discrepancyJustification;
    if (reconciliation.hasDiscrepancy) {
      discrepancyJustification = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => POReconciliationWarningDialog(report: reconciliation),
      );

      // User chose "الرجوع للتعديل" (Back to Edit)
      if (discrepancyJustification == null || !mounted) {
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 1.0;

    // Build final notes with justification if provided
    String? effectiveNotes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    if (discrepancyJustification != null && discrepancyJustification.isNotEmpty) {
      final header = '[مبررات اختلاف الفاتورة والباكينج]: $discrepancyJustification';
      effectiveNotes = effectiveNotes == null ? header : '$effectiveNotes\n$header';
    }

    if (widget.po == null) {
      final int effectivePalletCount = _isDirectVolumeMode ? _dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount) : 0;
      final firstPallet = (_isDirectVolumeMode && _dialogPalletItems.isNotEmpty) ? _dialogPalletItems.first : null;
      final effectivePalletType = firstPallet?.palletType ?? _selectedPalletType;
      final effectiveIsStackable = firstPallet?.isStackable ?? _isPalletStackable;
      final effectivePalletL = firstPallet?.lengthCm ?? _palletLengthCm;
      final effectivePalletW = firstPallet?.widthCm ?? _palletWidthCm;
      final effectivePalletH = firstPallet?.heightCm ?? _palletHeightCm;
      final effectivePalletPlan = _isDirectVolumeMode ? _dialogPalletItems : <PalletPlanItemModel>[];

      final newPO = PurchaseOrderModel(
        poNumber: '',
        poReference: _poReferenceCtrl.text.trim().isEmpty ? null : _poReferenceCtrl.text.trim(),
        proformaInvoiceNumber: _piCtrl.text.trim().isEmpty ? null : _piCtrl.text.trim(),
        countryOfOrigin: _selectedCountryOfOrigin,
        importFileId: _selectedImportFileId,
        projectId: _selectedProjectId!,
        companyId: _selectedCompanyId!,
        supplierId: _selectedSupplierId!,
        incotermId: _selectedIncotermId!,
        currencyId: _selectedCurrencyId!,
        orderDate: _selectedOrderDate,
        exchangeRate: rate,
        paymentTerms: _selectedPaymentTerms,
        palletCount: effectivePalletCount,
        palletType: effectivePalletType,
        isPalletStackable: effectiveIsStackable,
        palletLengthCm: effectivePalletL,
        palletWidthCm: effectivePalletW,
        palletHeightCm: effectivePalletH,
        palletPlanItems: effectivePalletPlan,
        status: _selectedStatus,
        notes: effectiveNotes,
        items: _dialogItems,
        packingListItems: _dialogPackingItems,
      );
      final errorMsg = await ref.read(purchaseOrdersProvider.notifier).createPurchaseOrder(newPO);
      if (!mounted) return;
      if (errorMsg != null) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('خطأ في إدخال أمر الشراء:\n$errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        await PODraftManager.clearDraft(widget.po?.poId);
        _isDirty = false;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء وحفظ أمر الشراء بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        if (context.mounted) Navigator.pop(context);
      }
    } else {
      final oldPO = widget.po!;
      final List<FieldChangeItem> changes = [];
      final projects = ref.read(projectsProvider).valueOrNull ?? [];
      final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
      final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
      final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
      final currencies = ref.read(currenciesProvider).valueOrNull ?? [];

      // 1. Header changes
      final newPoRef = _poReferenceCtrl.text.trim().isEmpty ? null : _poReferenceCtrl.text.trim();
      if (FieldChangeItem.isDifferent(oldPO.poReference, newPoRef)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'اسم / مرجع أمر الشراء (PO Reference)',
          oldValue: oldPO.poReference,
          newValue: newPoRef,
        ));
      }

      final newPi = _piCtrl.text.trim().isEmpty ? null : _piCtrl.text.trim();
      if (FieldChangeItem.isDifferent(oldPO.proformaInvoiceNumber, newPi)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'رقم الفاتورة المبدئية (PI Number)',
          oldValue: oldPO.proformaInvoiceNumber,
          newValue: newPi,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.countryOfOrigin, _selectedCountryOfOrigin)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'بلد المنشأ (Country of Origin)',
          oldValue: oldPO.countryOfOrigin,
          newValue: _selectedCountryOfOrigin,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.projectId, _selectedProjectId)) {
        final oldProj = projects.where((p) => p.projectId == oldPO.projectId).firstOrNull?.projectName ?? '${oldPO.projectId}';
        final newProj = projects.where((p) => p.projectId == _selectedProjectId).firstOrNull?.projectName ?? '$_selectedProjectId';
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'المشروع الاستيرادي',
          oldValue: oldProj,
          newValue: newProj,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.companyId, _selectedCompanyId)) {
        final oldComp = companies.where((c) => c.companyId == oldPO.companyId).firstOrNull?.importerName ?? '${oldPO.companyId}';
        final newComp = companies.where((c) => c.companyId == _selectedCompanyId).firstOrNull?.importerName ?? '$_selectedCompanyId';
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'الشركة المستوردة',
          oldValue: oldComp,
          newValue: newComp,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.supplierId, _selectedSupplierId)) {
        final oldSupp = suppliers.where((s) => s.supplierId == oldPO.supplierId).firstOrNull?.companyName ?? '${oldPO.supplierId}';
        final newSupp = suppliers.where((s) => s.supplierId == _selectedSupplierId).firstOrNull?.companyName ?? '$_selectedSupplierId';
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'المورد الأجنبي',
          oldValue: oldSupp,
          newValue: newSupp,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.incotermId, _selectedIncotermId)) {
        final oldInco = incoterms.where((i) => i.incotermId == oldPO.incotermId).firstOrNull?.incotermCode ?? '${oldPO.incotermId}';
        final newInco = incoterms.where((i) => i.incotermId == _selectedIncotermId).firstOrNull?.incotermCode ?? '$_selectedIncotermId';
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'شرط الشحن (Incoterm)',
          oldValue: oldInco,
          newValue: newInco,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.currencyId, _selectedCurrencyId)) {
        final oldCurr = currencies.where((c) => c.currencyId == oldPO.currencyId).firstOrNull?.currencyCode ?? '${oldPO.currencyId}';
        final newCurr = currencies.where((c) => c.currencyId == _selectedCurrencyId).firstOrNull?.currencyCode ?? '$_selectedCurrencyId';
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'عملة أمر الشراء',
          oldValue: oldCurr,
          newValue: newCurr,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.exchangeRate, rate)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'سعر الصرف',
          oldValue: oldPO.exchangeRate,
          newValue: rate,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.paymentTerms, _selectedPaymentTerms)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'شروط السداد والدفع',
          oldValue: oldPO.paymentTerms,
          newValue: _selectedPaymentTerms,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.status, _selectedStatus)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'حالة أمر الشراء',
          oldValue: oldPO.status,
          newValue: _selectedStatus,
        ));
      }

      if (FieldChangeItem.isDifferent(oldPO.notes, effectiveNotes)) {
        changes.add(FieldChangeItem(
          section: 'بيانات الفاتورة المبدئية والترويسة',
          fieldName: 'الملاحظات',
          oldValue: oldPO.notes,
          newValue: effectiveNotes,
        ));
      }

      // 2. Line Items
      if (oldPO.items.length != _dialogItems.length) {
        changes.add(FieldChangeItem(
          section: 'بنود الفاتورة المبدئية',
          fieldName: 'عدد بنود الفاتورة',
          oldValue: '${oldPO.items.length} بند',
          newValue: '${_dialogItems.length} بند',
        ));
      } else {
        for (int i = 0; i < _dialogItems.length; i++) {
          final o = oldPO.items[i];
          final n = _dialogItems[i];
          if (FieldChangeItem.isDifferent(o.descriptionAr, n.descriptionAr)) {
            changes.add(FieldChangeItem(
              section: 'بنود الفاتورة المبدئية',
              fieldName: 'بند #${i + 1} - الوصف العربي',
              oldValue: o.descriptionAr,
              newValue: n.descriptionAr,
            ));
          }
          if (FieldChangeItem.isDifferent(o.quantity, n.quantity)) {
            changes.add(FieldChangeItem(
              section: 'بنود الفاتورة المبدئية',
              fieldName: 'بند #${i + 1} (${n.itemCode ?? ""}) - الكمية',
              oldValue: o.quantity,
              newValue: n.quantity,
            ));
          }
          if (FieldChangeItem.isDifferent(o.unitPrice, n.unitPrice)) {
            changes.add(FieldChangeItem(
              section: 'بنود الفاتورة المبدئية',
              fieldName: 'بند #${i + 1} (${n.itemCode ?? ""}) - سعر الوحدة',
              oldValue: o.unitPrice,
              newValue: n.unitPrice,
            ));
          }
        }
      }

      // 3. Packing List Items
      if (oldPO.packingListItems.length != _dialogPackingItems.length) {
        changes.add(FieldChangeItem(
          section: 'قائمة التعبئة (Packing List)',
          fieldName: 'عدد طرود قائمة التعبئة',
          oldValue: '${oldPO.packingListItems.length} طرد',
          newValue: '${_dialogPackingItems.length} طرد',
        ));
      } else {
        for (int i = 0; i < _dialogPackingItems.length; i++) {
          final o = oldPO.packingListItems[i];
          final n = _dialogPackingItems[i];
          if (FieldChangeItem.isDifferent(o.itemCode, n.itemCode)) {
            changes.add(FieldChangeItem(
              section: 'قائمة التعبئة (Packing List)',
              fieldName: 'طرد #${i + 1} - كود البند',
              oldValue: o.itemCode,
              newValue: n.itemCode,
            ));
          }
          if (FieldChangeItem.isDifferent(o.packageType, n.packageType)) {
            changes.add(FieldChangeItem(
              section: 'قائمة التعبئة (Packing List)',
              fieldName: 'طرد #${i + 1} (${n.itemCode}) - نوع الطرد',
              oldValue: o.packageType,
              newValue: n.packageType,
            ));
          }
          if (FieldChangeItem.isDifferent(o.qtyPkg, n.qtyPkg)) {
            changes.add(FieldChangeItem(
              section: 'قائمة التعبئة (Packing List)',
              fieldName: 'طرد #${i + 1} (${n.itemCode}) - عدد الطرود',
              oldValue: o.qtyPkg,
              newValue: n.qtyPkg,
            ));
          }
          if (FieldChangeItem.isDifferent(o.grossWeightUnitKg, n.grossWeightUnitKg)) {
            changes.add(FieldChangeItem(
              section: 'قائمة التعبئة (Packing List)',
              fieldName: 'طرد #${i + 1} (${n.itemCode}) - وزن الطرد (kg)',
              oldValue: o.grossWeightUnitKg,
              newValue: n.grossWeightUnitKg,
            ));
          }
          if (FieldChangeItem.isDifferent(o.isStackable, n.isStackable)) {
            changes.add(FieldChangeItem(
              section: 'قائمة التعبئة (Packing List)',
              fieldName: 'طرد #${i + 1} (${n.itemCode}) - تعليمات الرص',
              oldValue: o.isStackable ? '📦 قابل للرص' : '🚫 غير قابل للرص',
              newValue: n.isStackable ? '📦 قابل للرص' : '🚫 غير قابل للرص',
            ));
          }
        }
      }

      if (changes.isNotEmpty) {
        if (!context.mounted) return;
        final confirmed = await showChangeDiffConfirmationDialog(
          context,
          title: 'مراجعة وتأكيد تعديلات أمر الشراء',
          itemReference: oldPO.displayName,
          changes: changes,
        );
        if (!confirmed) {
          if (mounted) setState(() => _isSubmitting = false);
          return;
        }
      }

      final int effectivePalletCount = _isDirectVolumeMode ? _dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount) : 0;
      final firstPallet = (_isDirectVolumeMode && _dialogPalletItems.isNotEmpty) ? _dialogPalletItems.first : null;
      final effectivePalletType = firstPallet?.palletType ?? _selectedPalletType;
      final effectiveIsStackable = firstPallet?.isStackable ?? _isPalletStackable;
      final effectivePalletL = firstPallet?.lengthCm ?? _palletLengthCm;
      final effectivePalletW = firstPallet?.widthCm ?? _palletWidthCm;
      final effectivePalletH = firstPallet?.heightCm ?? _palletHeightCm;
      final effectivePalletPlan = _isDirectVolumeMode ? _dialogPalletItems.map((p) => p.toJson()).toList() : <Map<String, dynamic>>[];

      final updateData = {
        'po_reference': _poReferenceCtrl.text.trim().isEmpty ? null : _poReferenceCtrl.text.trim(),
        'proforma_invoice_number': _piCtrl.text.trim().isEmpty ? null : _piCtrl.text.trim(),
        'country_of_origin': _selectedCountryOfOrigin,
        'import_file_id': _selectedImportFileId,
        'project_id': _selectedProjectId!,
        'company_id': _selectedCompanyId!,
        'supplier_id': _selectedSupplierId!,
        'incoterm_id': _selectedIncotermId!,
        'currency_id': _selectedCurrencyId!,
        'order_date': _selectedOrderDate.toIso8601String(),
        'exchange_rate': rate,
        'payment_terms': _selectedPaymentTerms,
        'pallet_count': effectivePalletCount,
        'pallet_type': effectivePalletType,
        'is_pallet_stackable': effectiveIsStackable,
        'pallet_length_cm': effectivePalletL,
        'pallet_width_cm': effectivePalletW,
        'pallet_height_cm': effectivePalletH,
        'pallet_plan': effectivePalletPlan,
        'status': _selectedStatus,
        'notes': effectiveNotes,
        'version': widget.po?.version ?? 1,
        'items': _dialogItems.map((i) => i.toJson()).toList(),
        'packing_list_items': _dialogPackingItems.map((i) => i.toJson()).toList(),
      };
      final result = await ref.read(purchaseOrdersProvider.notifier).updatePurchaseOrder(widget.po!.poId!, updateData);
      if (!mounted || !context.mounted) return;

      if (result.isConflict) {
        setState(() => _isSubmitting = false);
        final conflict = result.conflictDetails ?? {};
        final resolution = await ConcurrencyConflictDialog.show(
          context,
          entityName: conflict['entity'] as String? ?? 'PurchaseOrder',
          recordId: conflict['record_id'] ?? widget.po!.poId!,
          currentVersion: (conflict['current_version'] as num?)?.toInt() ?? ((widget.po?.version ?? 1) + 1),
          submittedVersion: (conflict['submitted_version'] as num?)?.toInt() ?? (widget.po?.version ?? 1),
          updatedAt: conflict['updated_at'] as String?,
          updatedBy: conflict['updated_by'] as String?,
          serverMessage: conflict['message'] as String?,
          currentDraftData: updateData,
        );

        if (!mounted || !context.mounted) return;

        if (resolution == ConcurrencyResolution.discardAndReload) {
          await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
          if (mounted && context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إلغاء المسودة وإعادة تحميل أحدث نسخة من أمر الشراء بنجاح.'),
                backgroundColor: AppTheme.cobalt,
              ),
            );
          }
        }
        return;
      }

      if (!result.isSuccess) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث أمر الشراء:\n${result.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        await PODraftManager.clearDraft(widget.po?.poId);
        _isDirty = false;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التعديلات بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  void _showPoComprehensiveReportPreview(BuildContext context) {
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final incoterms = ref.read(incotermsProvider).valueOrNull ?? [];
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final projects = ref.read(projectsProvider).valueOrNull ?? [];
    final tariffs = ref.read(customsTariffProvider).valueOrNull ?? [];
    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];

    final comp = companies.where((c) => c.companyId == _selectedCompanyId).firstOrNull;
    final supp = suppliers.where((s) => s.supplierId == _selectedSupplierId).firstOrNull;
    final inco = incoterms.where((i) => i.incotermId == _selectedIncotermId).firstOrNull;
    final curr = currencies.where((c) => c.currencyId == _selectedCurrencyId).firstOrNull;
    final proj = projects.where((p) => p.projectId == _selectedProjectId).firstOrNull;
    final impF = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;

    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 1.0;

    POReportPreviewDialog.show(
      context: context,
      poNumber: widget.po?.poNumber ?? 'PO-NEW (Draft)',
      piNumber: _piCtrl.text.trim().isNotEmpty ? _piCtrl.text.trim() : null,
      orderDate: _selectedOrderDate,
      companyName: comp?.importerName ?? 'غير محدد (Select Company)',
      companyTaxId: comp?.vatId,
      supplierName: supp?.companyName ?? 'غير محدد (Select Supplier)',
      supplierCountry: supp?.foreignExporterCountry ?? _selectedCountryOfOrigin,
      incoterm: inco?.incotermCode ?? 'EXW',
      currency: curr?.currencyCode ?? 'USD',
      exchangeRate: rate,
      countryOfOrigin: _selectedCountryOfOrigin,
      paymentTerms: _selectedPaymentTerms,
      projectName: proj?.projectName,
      importFileCode: impF?.primaryNameWithCode ?? impF?.importFileCode ?? impF?.customFileNumber,
      items: _dialogItems,
      packingItems: _dialogPackingItems,
      palletItems: _isDirectVolumeMode ? _dialogPalletItems : <PalletPlanItemModel>[],
      tariffs: tariffs,
      isDirectVolumeMode: _isDirectVolumeMode,
      notes: _notesCtrl.text.trim(),
      onConfirmSave: () async {
        await _submitForm(context);
      },
    );
  }

  void _showPoVisualLoadPlannerDialog(BuildContext context, List<PackingListItemModel> packingItems) {
    final hasPallets = _isDirectVolumeMode && _dialogPalletItems.isNotEmpty && _dialogPalletItems.any((p) => p.palletCount > 0);
    List<CargoItem> cargoItems = [];

    if (hasPallets) {
      final double totalGross = packingItems.fold<double>(
        0.0,
        (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
      );
      final int totalPallets = _dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in _dialogPalletItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description: 'بالتة #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
          ));
          globalIdx++;
        }
      }
    } else {
      int globalIdx = 1;
      for (final p in packingItems) {
        final lCm = p.unit == 'mm' ? p.lengthCm / 10.0 : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
        final wCm = p.unit == 'mm' ? p.widthCm / 10.0 : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
        final hCm = p.unit == 'mm' ? p.heightCm / 10.0 : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
        final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
        final double unitGrossWt = p.grossWeightUnitKg > 0
            ? p.grossWeightUnitKg
            : (p.totalGrossWeightKg > 0 ? (p.totalGrossWeightKg / count) : 10.0);

        for (int i = 0; i < count; i++) {
          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: count > 1 ? '${p.itemCode} (طرد ${i + 1}/$count)' : p.itemCode,
          ));
          globalIdx++;
        }
      }
    }

    if (cargoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال أصناف قائمة التعبئة أو البالتات أولاً للمحاكاة')),
      );
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final GlobalKey formPlannerRepaintKey = GlobalKey();
    final poNumber = _poReferenceCtrl.text.trim().isNotEmpty ? _poReferenceCtrl.text.trim() : (widget.po?.poNumber ?? 'Draft');
    final displayName = 'PO $poNumber';
    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final plan = ContainerRequirementEngine.planShipment(
              cargoItems,
              forceStackable: activeStackingMode,
              forceOrientation: activeOrientationMode,
            );

            // Compute summary metrics for active plan
            final totalPkgs = cargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;

            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            // Determine container fleet text
            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummary = containerCounts.isEmpty
                ? 'لا توجد حاويات مناسبة'
                : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: 1180,
                height: 780,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 26),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.containerLoadPlan3dTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                                ),
                                Text(
                                  context.l10n.containerLoadPlan3dSubtitle,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
                              tooltip: isArabic ? 'تنزيل صور المحاكاة (PNG)' : 'Download Simulation Image (PNG)',
                              onPressed: () async {
                                await ContainerLoadPlanExportService.exportSimulationImage(
                                  context: dialogCtx,
                                  repaintKey: formPlannerRepaintKey,
                                  displayName: '$displayName - 3D Simulation',
                                  isArabic: isArabic,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                              tooltip: isArabic ? 'تنزيل مخطط التحميل (PDF)' : 'Download Loading Plan (PDF)',
                              onPressed: () async {
                                await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                                  context: dialogCtx,
                                  repaintKey: formPlannerRepaintKey,
                                  displayName: displayName,
                                  poNumber: poNumber,
                                  companyName: widget.po?.companyName,
                                  supplierName: widget.po?.supplierName,
                                  plan: plan,
                                  fleetSummary: fleetSummary,
                                  totalPlanWeight: totalPlanWeight,
                                  totalPlanVolume: totalPlanVolume,
                                  totalPkgs: totalPkgs,
                                  isArabic: isArabic,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Controls & Stacking Filter Row (Responsive Wrap to eliminate clipping)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🔄 ${context.l10n.stackingSimulationModeLabel}:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                              ),
                              ChoiceChip(
                                label: Text('✨ ${context.l10n.smartHybridOption}'),
                                selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                                selectedColor: AppTheme.emerald,
                                labelStyle: TextStyle(
                                  color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('📐 ${context.l10n.flatOnlyOption}'),
                                selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeOrientationMode = CargoOrientationPreference.flatOnly;
                                      activeStackingMode = true;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('🚫 ${context.l10n.simulationModeFloorOnly}'),
                                selected: activeStackingMode == false,
                                selectedColor: Colors.orange.shade800,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == false ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeStackingMode = false;
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: Text('🔀 ${context.l10n.simulationModeActualMixed}'),
                                selected: activeStackingMode == null,
                                selectedColor: AppTheme.charcoal,
                                labelStyle: TextStyle(
                                  color: activeStackingMode == null ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(() {
                                      activeStackingMode = null;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '👁️ ${context.l10n.projectionLabel}:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                              ),
                              ChoiceChip(
                                label: const Text('🖼️ كلاهما (Both Views)'),
                                selected: viewProjection == 'both',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'both' ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'both');
                                },
                              ),
                              ChoiceChip(
                                label: Text('📐 ${context.l10n.sideViewProjection}'),
                                selected: viewProjection == 'side',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'side' ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'side');
                                },
                              ),
                              ChoiceChip(
                                label: Text('🔝 ${context.l10n.topViewProjection}'),
                                selected: viewProjection == 'top',
                                selectedColor: AppTheme.cobalt,
                                labelStyle: TextStyle(
                                  color: viewProjection == 'top' ? Colors.white : AppTheme.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val) setDialogState(() => viewProjection = 'top');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fleet KPI Summary Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.charcoal.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 6),
                              Text(context.l10n.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: AppTheme.charcoal, size: 18),
                              const SizedBox(width: 6),
                              Text(context.l10n.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                              const SizedBox(width: 6),
                              Text(context.l10n.totalWeightSummary(PoPackingMatcher.formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                              const SizedBox(width: 6),
                              Text(context.l10n.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Plan Containers List
                    Expanded(
                      child: RepaintBoundary(
                        key: formPlannerRepaintKey,
                        child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      res.failureReason ?? context.l10n.packingFailureTitle,
                                      style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                          final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          context.l10n.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobalt.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          context.l10n.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                   if (viewProjection == 'both') ...[
                                     // Side View (Left Wall Removed)
                                     Container(
                                       height: 200,
                                       width: double.infinity,
                                       decoration: BoxDecoration(
                                         color: Colors.grey.shade900,
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: CustomPaint(
                                         painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                       ),
                                     ),
                                     const SizedBox(height: 10),
                                     // Top View (Roof Removed)
                                     Container(
                                       height: 155,
                                       width: double.infinity,
                                       decoration: BoxDecoration(
                                         color: Colors.grey.shade900,
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: CustomPaint(
                                         painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                       ),
                                     ),
                                   ] else ...[
                                     Container(
                                       height: 360,
                                       width: double.infinity,
                                       decoration: BoxDecoration(
                                         color: Colors.grey.shade900,
                                         borderRadius: BorderRadius.circular(4),
                                       ),
                                       child: CustomPaint(
                                         painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                                       ),
                                     ),
                                   ],
                                   const SizedBox(height: 10),

                                   // Placed Items Details Table (Aggregated by Item Rule)
                                   Theme(
                                     data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                     child: ExpansionTile(
                                       initiallyExpanded: true,
                                       tilePadding: EdgeInsets.zero,
                                       title: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Text(
                                             showDetailedCoordinates
                                                 ? '📐 تفاصيل الرص الإحداثي (${res.placedItems.length} طرد)'
                                                 : '📊 الأصناف المرصوصة مجمعة (${res.groupedItems.length} صنف | إجمالي ${res.placedItems.length} طرد)',
                                             style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                           ),
                                           OutlinedButton.icon(
                                             style: OutlinedButton.styleFrom(
                                               visualDensity: VisualDensity.compact,
                                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                               foregroundColor: AppTheme.cobalt,
                                               side: const BorderSide(color: AppTheme.cobalt),
                                             ),
                                             icon: Icon(showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered, size: 14),
                                             label: Text(
                                               showDetailedCoordinates ? 'عرض مجمع حسب الأصناف' : 'عرض تفصيلي بالإحداثيات',
                                               style: const TextStyle(fontSize: 11),
                                             ),
                                             onPressed: () => setDialogState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                           ),
                                         ],
                                       ),
                                       children: [
                                         if (!showDetailedCoordinates)
                                           Table(
                                             border: TableBorder.all(color: Colors.grey.shade300),
                                             columnWidths: const {
                                               0: FlexColumnWidth(0.6),
                                               1: FlexColumnWidth(2.5),
                                               2: FlexColumnWidth(1.2),
                                               3: FlexColumnWidth(1.6),
                                               4: FlexColumnWidth(1.2),
                                               5: FlexColumnWidth(1.8),
                                               6: FlexColumnWidth(1.2),
                                               7: FlexColumnWidth(1.2),
                                             },
                                             children: [
                                               TableRow(
                                                 decoration: BoxDecoration(color: Colors.grey.shade200),
                                                 children: const [
                                                   Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('الصنف / البند', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('نوع الطرد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('الأبعاد (سم)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('العدد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('إجمالي الوزن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('الحجم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: EdgeInsets.all(6), child: Text('الرص', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                 ],
                                               ),
                                               ...res.groupedItems.asMap().entries.map((entry) {
                                                 final idx = entry.key + 1;
                                                 final g = entry.value;
                                                 return TableRow(
                                                   children: [
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(
                                                       padding: const EdgeInsets.all(6),
                                                       child: Container(
                                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                         decoration: BoxDecoration(
                                                           color: AppTheme.cobalt.withOpacity(0.12),
                                                           borderRadius: BorderRadius.circular(4),
                                                         ),
                                                         child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                       ),
                                                     ),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('${PoPackingMatcher.formatWeight(g.totalWeight)} kg', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? '📦 نعم' : '🚫 أرضي', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                   ],
                                                 );
                                               }),
                                             ],
                                           )
                                         else
                                           Table(
                                             border: TableBorder.all(color: Colors.grey.shade300),
                                             columnWidths: const {
                                               0: FlexColumnWidth(0.8),
                                               1: FlexColumnWidth(2.2),
                                               2: FlexColumnWidth(1.8),
                                               3: FlexColumnWidth(1.2),
                                               4: FlexColumnWidth(2.0),
                                               5: FlexColumnWidth(1.2),
                                             },
                                             children: [
                                               TableRow(
                                                 decoration: BoxDecoration(color: Colors.grey.shade200),
                                                 children: [
                                                   const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thPackageCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                   Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                   Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                 ],
                                               ),
                                               ...res.placedItems.asMap().entries.map((entry) {
                                                 final idx = entry.key + 1;
                                                 final item = entry.value;
                                                 return TableRow(
                                                   children: [
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(PoPackingMatcher.formatWeight(item.item.weight), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                                     Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? '📦 نعم' : '🚫 أرضي', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                   ],
                                                 );
                                               }),
                                             ],
                                           ),
                                       ],
                                     ),
                                   ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                     ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// // Tab Keep-Alive Wrapper for Zero-Latency Tab Switching
// ==================================================
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}