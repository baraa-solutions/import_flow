import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';

  void showTariffDialog(BuildContext context, WidgetRef ref,
      {CustomsTariffModel? tariff, int initialModeIndex = 0}) {
    final l10n = context.l10n;
    final hsCtrl = TextEditingController(text: tariff?.hsCode ?? '');
    final descCtrl = TextEditingController(text: tariff?.hsDescription ?? '');
    // The category is a CUSTOMS_CATEGORY code; legacy labels preselect their code and an
    // unknown legacy text stays selectable as an extra item. catCtrl holds the selected value.
    final initialCategory =
        DomainEnums.initialCode(DomainEnumType.customsCategory, tariff?.customsCategory, tariff?.customsCategory?.trim() ?? '');
    final catCtrl = TextEditingController(text: initialCategory);

    final dutyCtrl = TextEditingController(
        text: tariff?.customsDutyRate.toString() ?? '0.00');
    final vatCtrl =
        TextEditingController(text: tariff?.vatRate.toString() ?? '14.00');
    final schedCtrl = TextEditingController(
        text: tariff?.scheduleTaxRate.toString() ?? '0.00');
    final devCtrl = TextEditingController(
        text: tariff?.developmentFeeRate.toString() ?? '0.00');
    final importFeeCtrl =
        TextEditingController(text: tariff?.importFeeRate.toString() ?? '0.00');

    final authCtrl =
        TextEditingController(text: tariff?.regulatoryAuthority ?? '');
    final priorApprovalCtrl =
        TextEditingController(text: tariff?.priorApprovalNote ?? '');
    final notesCtrl = TextEditingController(text: tariff?.notes ?? '');

    final rawTextCtrl = TextEditingController();

    bool requiresCoo = tariff?.requiresCoo ?? false;
    bool requiresInspection = tariff?.requiresInspection ?? false;
    bool requiresAcid = tariff?.requiresAcid ?? true;

    int activeModeIndex = tariff != null ? 1 : initialModeIndex; // 0 = Smart Text, 1 = Manual Form
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? parseError;

    // Parsed preview state
    Map<String, dynamic>? parsedTariffData;
    List<Map<String, dynamic>> parsedAgreements = [];
    Map<String, dynamic>? parsedComparisonData;

    void doLocalParse(String text, void Function(void Function()) setDialogState) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        setDialogState(() {
          parsedTariffData = null;
          parsedAgreements = [];
          parsedComparisonData = null;
          parseError = null;
        });
        return;
      }

      try {
        // 1. HS Code
        final hsMatch = RegExp(r'رقم\s*البند\s*:\s*([\d\.\s]+)').firstMatch(trimmed) ??
            RegExp(r'\b(\d{8,10})\b').firstMatch(trimmed);
        final hsCodeVal = hsMatch != null ? hsMatch.group(1)!.replaceAll('.', '').trim() : '';

        // 2. Description
        final descMatch = RegExp(r'نص\s*البند\s*:\s*(.*?)(?=\n\s*الضرائب|\n\s*المستندات|$)', dotAll: true).firstMatch(trimmed);
        final descVal = descMatch != null ? descMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim() : 'بند جمركي';

        // 3. Duty Rate
        final dutyMatch = RegExp(r'ضريبة\s*الوارد\s*\(\s*النظام\s*الاساسي\s*\)\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed) ??
            RegExp(r'ضريبة\s*الوارد\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
        final dutyVal = dutyMatch != null ? (double.tryParse(dutyMatch.group(1)!) ?? 0.0) : 0.0;

        // 4. VAT Rate
        final vatMatch = RegExp(r'ضريبة\s*قيمه\s*مضافه\s*:\s*([\d\.]+)\s*%|ضريبة\s*القيمة\s*المضافة\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
        final vatVal = vatMatch != null ? (double.tryParse(vatMatch.group(1) ?? vatMatch.group(2) ?? '14.0') ?? 14.0) : 14.0;

        // 5. Schedule Tax Rate
        final schedMatch = RegExp(r'ضريبة\s*الجدول\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
        final schedVal = schedMatch != null ? (double.tryParse(schedMatch.group(1)!) ?? 0.0) : 0.0;

        // 6. Development Fee
        final devMatch = RegExp(r'رسم\s*التنمية\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
        final devVal = devMatch != null ? (double.tryParse(devMatch.group(1)!) ?? 0.0) : 0.0;

        // 7. Import Fee
        final impMatch = RegExp(r'رسم\s*الوارد\s*:\s*([\d\.]+)\s*%').firstMatch(trimmed);
        final impVal = impMatch != null ? (double.tryParse(impMatch.group(1)!) ?? 0.0) : 0.0;

        // 8. Documents & Prior Approvals
        final List<String> priorList = [];
        final List<String> authorities = [];
        bool reqInspection = false;

        final docSectionMatch = RegExp(r'المستندات\s*والأعمال\s*:(.*)', dotAll: true).firstMatch(trimmed);
        final List<Map<String, dynamic>> extractedAgreements = [];

        if (docSectionMatch != null) {
          final lines = docSectionMatch.group(1)!.split('\n');
          final List<String> consolidated = [];
          List<String> block = [];
          for (var l in lines) {
            final ls = l.trim();
            if (ls.isEmpty) {
              if (block.isNotEmpty) {
                consolidated.add(block.join(' '));
                block = [];
              }
            } else if (ls.startsWith('ر') || ls.startsWith('ق')) {
              if (block.isNotEmpty) {
                consolidated.add(block.join(' '));
                block = [];
              }
              block.add(ls);
            } else {
              block.add(ls);
            }
          }
          if (block.isNotEmpty) consolidated.add(block.join(' '));

          for (var dline in consolidated) {
            if (dline.startsWith('ق') || dline.contains('لايصرح') || dline.contains('لايفرج') || dline.contains('يشترط') || dline.contains('لا يتم استيراد')) {
              priorList.add(dline);
              reqInspection = true;
            }
            if (dline.contains('هـ .ع.ص.و') || dline.contains('هـ.ع.ص.و') || dline.contains('الصادرات والواردات')) {
              if (!authorities.contains('الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)')) {
                authorities.add('الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)');
              }
            }
            if (dline.contains('البيئة') || dline.contains('الأوزون') || dline.contains('الاوزون')) {
              if (!authorities.contains('جهاز شئون البيئة (EEAA)')) {
                authorities.add('جهاز شئون البيئة (EEAA)');
              }
            }

            if (dline.startsWith('ر') || dline.contains('اتفاقية') || dline.contains('تخفض') || dline.contains('يعفى')) {
              final notMatch = RegExp(r'(ر\d{4,5})').firstMatch(dline);
              final pubNotice = notMatch?.group(1);

              String name = 'اتفاقية تفضيلية (${pubNotice ?? "خاصة"})';
              String countries = 'OTHER';
              String doc = 'شهادة منشأ تفضيلية معتمدة';
              double? prefRate;

              if (dline.contains('صربيا')) {
                name = 'اتفاقية صربيا للتجارة الحرة';
                countries = 'RS';
                doc = 'شهادة منشأ صربية / EUR.1';
                prefRate = (dutyVal * 0.90);
              } else if (dline.contains('المملكة المتحدة')) {
                name = 'اتفاقية الشراكة المصرية والمملكة المتحدة (UK Partnership)';
                countries = 'GB';
                doc = 'شهادة منشأ المملكة المتحدة / EUR.1';
                prefRate = 0.0;
              } else if (dline.contains('ميركسور')) {
                name = 'اتفاقية أمريكا اللاتينية الميركسور (Mercosur)';
                countries = 'BR,AR,UY,PY';
                doc = 'شهادة منشأ اتفاقية الميركسور';
              } else if (dline.contains('تركيا')) {
                name = 'اتفاقية التجارة الحرة مع تركيا (Turkey FTA)';
                countries = 'TR';
                doc = 'شهادة EUR.1';
                prefRate = 0.0;
              } else if (dline.contains('الافتا') || dline.contains('الإفتا')) {
                name = 'اتفاقية دول الإفتا (EFTA)';
                countries = 'IS,LI,NO,CH';
                doc = 'شهادة EUR.1 / EFTA';
                prefRate = 0.0;
              } else if (dline.contains('أوربية') || dline.contains('أوروبية')) {
                name = 'اتفاقية الشراكة الأوروبية (EU Partnership)';
                countries = 'DE,FR,IT,ES,NL,BE,AT,SE,DK,FI,GR,PT,IE,PL,CZ,HU,RO,BG,HR,SK,SI,CY,MT,EE,LV,LT';
                doc = 'شهادة EUR.1';
                prefRate = 0.0;
              }

              extractedAgreements.add({
                'hs_code': hsCodeVal,
                'agreement_name': name,
                'reduction_type': prefRate == 0.0 ? 'full_duty_exemption' : 'percentage_of_duty',
                'reduction_percentage': prefRate == 0.0 ? 1.0 : (dline.contains('10%') ? 0.10 : 1.0),
                'preferential_duty_rate': prefRate,
                'publication_notice': pubNotice,
                'required_document': doc,
                'origin_countries': countries,
                'conditions_note': dline,
              });
            }
          }
        }

        final priorNote = priorList.isNotEmpty ? priorList.join('\n\n') : null;
        final authVal = authorities.isNotEmpty
            ? authorities.join(' / ')
            : (reqInspection ? 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)' : null);

        setDialogState(() {
          parsedTariffData = {
            'hs_code': hsCodeVal,
            'hs_description': descVal,
            'customs_category': (descVal.contains('آلات') || descVal.contains('أجهزة') || descVal.contains('تكييف')) ? 'MACHINERY_EQUIPMENT' : 'GENERAL_GOODS',
            'customs_duty_rate': dutyVal,
            'vat_rate': vatVal,
            'schedule_tax_rate': schedVal,
            'development_fee_rate': devVal,
            'import_fee_rate': impVal,
            'customs_service_fee_rate': 1.0,
            'requires_coo': true,
            'requires_inspection': reqInspection,
            'requires_acid': true,
            'regulatory_authority': authVal,
            'prior_approval_note': priorNote,
          };
          parsedAgreements = extractedAgreements;
          parseError = null;

          // Also synchronize manual text controllers so switching tabs is seamless
          if (hsCodeVal.isNotEmpty) hsCtrl.text = hsCodeVal;
          if (descVal.isNotEmpty) descCtrl.text = descVal;
          dutyCtrl.text = dutyVal.toStringAsFixed(2);
          vatCtrl.text = vatVal.toStringAsFixed(2);
          schedCtrl.text = schedVal.toStringAsFixed(2);
          devCtrl.text = devVal.toStringAsFixed(2);
          importFeeCtrl.text = impVal.toStringAsFixed(2);
          if (authVal != null) authCtrl.text = authVal;
          if (priorNote != null) priorApprovalCtrl.text = priorNote;
          requiresInspection = reqInspection;
          requiresCoo = true;
          requiresAcid = true;
        });

        // Trigger asynchronous diff & version history lookup
        if (trimmed.length > 25) {
          ref.read(customsTariffProvider.notifier).parseSmartNafezaText(trimmed).then((res) {
            if (res != null && res['comparison'] != null) {
              setDialogState(() {
                parsedComparisonData = res['comparison'];
              });
            }
          }).catchError((_) {});
        }
      } catch (e) {
        setDialogState(() {
          parseError = 'تعذر استخراج بيانات البند: $e';
        });
      }
    }

    bool isDirty() {
      if (rawTextCtrl.text.trim().isNotEmpty) return true;
      if (hsCtrl.text.trim() != (tariff?.hsCode ?? '')) return true;
      if (descCtrl.text.trim() != (tariff?.hsDescription ?? '')) return true;
      if (catCtrl.text.trim() != initialCategory) return true;
      if (notesCtrl.text.trim() != (tariff?.notes ?? '')) return true;
      return false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => UnsavedChangesGuard(
          isDirty: isDirty(),
          child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tariff == null
                      ? l10n.tariffDialogTitleAdd
                      : l10n.tariffDialogTitleEdit(tariff.hsCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 720,
              height: 580,
              child: Column(
                children: [
                  // Top Segmented Mode Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => activeModeIndex = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeModeIndex == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: activeModeIndex == 0
                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.content_paste_go,
                                      size: 16,
                                      color: activeModeIndex == 0 ? AppTheme.cobalt : Colors.grey.shade700),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l10n.tariffModeSmartText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: activeModeIndex == 0 ? FontWeight.bold : FontWeight.normal,
                                        color: activeModeIndex == 0 ? AppTheme.cobalt : Colors.grey.shade800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => activeModeIndex = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeModeIndex == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: activeModeIndex == 1
                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tune,
                                      size: 16,
                                      color: activeModeIndex == 1 ? AppTheme.cobalt : Colors.grey.shade700),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      l10n.tariffModeManualForm,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: activeModeIndex == 1 ? FontWeight.bold : FontWeight.normal,
                                        color: activeModeIndex == 1 ? AppTheme.cobalt : Colors.grey.shade800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // Content View
                Expanded(
                  child: activeModeIndex == 0
                      // ================= SMART TEXT MODE =================
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick Examples Toolbar
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Text(l10n.quickExamplesLabel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    ActionChip(
                                      avatar: const Icon(Icons.ac_unit, size: 14, color: AppTheme.cobalt),
                                      label: Text(l10n.exampleAirConditioners, style: const TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        rawTextCtrl.text = '''رقم البند :
8415820010
نص البند :
آلات وأجهزة تكييف أخر متضمنة وحدة تبريد ، وحدات كاملة .
الضرائب :
ضريبة الوارد :
60.000 %
ضريبة الجدول :
8.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ق4518 - لايصرح باستيراد صنف الا بموافقة مختومة بخاتم شعارجمهوريةمن هـ .ع.ص.وطبقا لملحق8 وتعديلاته
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ق9994 - لايفرج عن صنف بضاعة مرشدةللمنطقة الحرة الابحصص لكل مستورد يحددهاجهاز تنفيذى للمنطقةالحرة
ر6704 - فى ظل اتفاق التجارة الحرة بين مصر وتجمع الميركسور تحصل ضريبة جمركية بنسبة 3%
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100%
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2''';
                                        doLocalParse(rawTextCtrl.text, setDialogState);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.category_outlined, size: 14, color: AppTheme.orange),
                                      label: Text(l10n.examplePlasticsBuilding, style: const TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        rawTextCtrl.text = '''رقم البند :
3925900090
نص البند :
أصناف أخر لتجهيزات البناء من لدائن ، غير مذكورة أو داخلة في مكان أخر .
الضرائب :
ضريبة الوارد (النظام الاساسي) :
40.000 %
ضريبة الوارد (اتفاقية أمريكا اللاتينية الميركسور) :
3.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ر6706 - تحصل ض. وارد طبقا للفئات الموضحة قرين كل بند على سلع واردة فى إطار إتفاقيةالميركسور
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100% على اصناف واردةبالقائمة 1 برتوكول 1
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2''';
                                        doLocalParse(rawTextCtrl.text, setDialogState);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    TextButton.icon(
                                      icon: const Icon(Icons.clear_all, size: 16, color: Colors.grey),
                                      label: Text(l10n.clearTextBtn, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      onPressed: () {
                                        rawTextCtrl.clear();
                                        doLocalParse('', setDialogState);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextFormField(
                                controller: rawTextCtrl,
                                maxLines: 8,
                                decoration: InputDecoration(
                                  labelText: l10n.pasteTariffBlockLabel,
                                  hintText: l10n.pasteTariffBlockHint,
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                                        tooltip: l10n.copyTooltip,
                                        onPressed: () => CopyHelper.copy(context, rawTextCtrl.text),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.auto_fix_high, color: AppTheme.cobalt),
                                        tooltip: l10n.parseNowTooltip,
                                        onPressed: () => doLocalParse(rawTextCtrl.text, setDialogState),
                                      ),
                                    ],
                                  ),
                                ),
                                onChanged: (val) => doLocalParse(val, setDialogState),
                              ),
                              if (parseError != null) ...[
                                const SizedBox(height: 8),
                                Text('⚠️ $parseError', style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ],
                              const SizedBox(height: 10),

                              // Live Parsed Preview Box
                              if (parsedTariffData != null && (parsedTariffData!['hs_code'] as String).isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            l10n.parsedPreviewHeader(parsedTariffData!['hs_code']),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald),
                                          ),
                                          const Spacer(),
                                          TextButton.icon(
                                            onPressed: () => setDialogState(() => activeModeIndex = 1),
                                            icon: const Icon(Icons.edit, size: 14),
                                            label: Text(l10n.editFieldsManuallyBtn, style: const TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'الوصف: ${parsedTariffData!['hs_description']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Chip(
                                            label: Text('ضريبة الوارد: ${parsedTariffData!['customs_duty_rate']}%'),
                                            backgroundColor: Colors.blue.shade50,
                                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          Chip(
                                            label: Text('ضريبة الجدول: ${parsedTariffData!['schedule_tax_rate']}%'),
                                            backgroundColor: Colors.purple.shade50,
                                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          Chip(
                                            label: Text('القيمة المضافة: ${parsedTariffData!['vat_rate']}%'),
                                            backgroundColor: Colors.green.shade50,
                                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      if (parsedTariffData!['regulatory_authority'] != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'الجهة الرقابية: ${parsedTariffData!['regulatory_authority']}',
                                          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                      if (parsedAgreements.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'الاتفاقيات التفضيلية المستخرجة (${parsedAgreements.length} اتفاقية):',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: parsedAgreements.map((ag) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.amber.shade300),
                                              ),
                                              child: Text(
                                                '${ag['publication_notice'] ?? ""}: ${ag['agreement_name']} ${ag['preferential_duty_rate'] != null ? "(${ag['preferential_duty_rate']}%)" : ""}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // Diff Comparison & Version History Section
                              if (parsedComparisonData != null) ...[
                                const SizedBox(height: 12),
                                Builder(builder: (context) {
                                  final comp = parsedComparisonData!;
                                  final hasPrev = comp['has_previous_version'] == true;
                                  final prevFrom = comp['previous_effective_from'];
                                  final prevTo = comp['previous_effective_to'];
                                  final newFrom = comp['new_effective_from'];
                                  final diffItems = (comp['diff_items'] as List?) ?? [];

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.shade400),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.history_edu, color: AppTheme.orange, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              hasPrev
                                                  ? l10n.diffHistoryTitle
                                                  : l10n.newHsVersionTitle,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.charcoal,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (hasPrev) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '📅 النسخة السابقة: من ${prevFrom ?? "—"} حتى ${prevTo ?? "اليوم"}',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.crimson),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    '⚡ النسخة الجديدة سارية من: ${newFrom ?? "اليوم"}',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (comp['summary_ar'] != null)
                                          Text(
                                            comp['summary_ar'],
                                            style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                                          ),
                                        if (diffItems.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.diffDetailsHeader,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          const SizedBox(height: 6),
                                          ...diffItems.map((item) {
                                            final hexColorStr = item['color_code'] ?? '#2C3E50';
                                            final colorVal = int.tryParse(hexColorStr.replaceFirst('#', '0xFF')) ?? 0xFF2C3E50;
                                            final itemColor = Color(colorVal);
                                            final changeType = item['change_type'] ?? 'unchanged';

                                            IconData icon = Icons.info_outline;
                                            if (changeType == 'added') icon = Icons.add_circle_outline;
                                            if (changeType == 'removed') icon = Icons.remove_circle_outline;
                                            if (changeType == 'modified') icon = Icons.edit_note;

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: itemColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: itemColor.withOpacity(0.4)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(icon, size: 14, color: itemColor),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item['summary_ar'] ?? item['description_ar'] ?? item['agreement_name'] ?? '',
                                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: itemColor),
                                                        ),
                                                        if (item['old_value_desc'] != null && item['new_value_desc'] != null)
                                                          Text(
                                                            'السابق: ${item['old_value_desc']} ➔ الجديد: ${item['new_value_desc']}',
                                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (item['publication_notice'] != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: itemColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item['publication_notice'],
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: itemColor),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        )
                      // ================= MANUAL FORM MODE =================
                      : Form(
                          key: formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: hsCtrl,
                                        enabled: tariff == null,
                                        decoration: InputDecoration(
                                          labelText: l10n.hsCodeLabelReq,
                                          hintText: l10n.hsCodeHint,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, hsCtrl.text),
                                          ),
                                        ),
                                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsCodeRequiredError : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SearchableDropdownField<String>(
                                        value: catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                                        labelText: l10n.customsCategoryLabel,
                                        hintText: l10n.customsCategoryHint,
                                        items: [
                                          for (final code in DomainEnums.codesOf(DomainEnumType.customsCategory))
                                            SearchableDropdownItem<String>(
                                              value: code,
                                              label: DomainEnums.label(l10n, DomainEnumType.customsCategory, code),
                                            ),
                                          if (catCtrl.text.trim().isNotEmpty &&
                                              !DomainEnums.isCode(DomainEnumType.customsCategory, catCtrl.text.trim()))
                                            SearchableDropdownItem<String>(
                                              value: catCtrl.text.trim(),
                                              label: catCtrl.text.trim(),
                                            ),
                                        ],
                                        onChanged: (v) => setDialogState(() => catCtrl.text = v ?? ''),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: descCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.hsDescriptionLabelReq,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      tooltip: l10n.copyTooltip,
                                      onPressed: () => CopyHelper.copy(context, descCtrl.text),
                                    ),
                                  ),
                                  maxLines: 2,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.hsDescriptionRequiredError : null,
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(l10n.taxRatesBreakdownSection,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: dutyCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.dutyRateInputLabel,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, dutyCtrl.text),
                                          ),
                                        ),
                                        validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.invalidNumberError : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: vatCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.vatRateInputLabel,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, vatCtrl.text),
                                          ),
                                        ),
                                        validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.invalidNumberError : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: schedCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.scheduleTaxInputLabel,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, schedCtrl.text),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: devCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.devFeeInputLabel,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, devCtrl.text),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: importFeeCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: l10n.importFeeInputLabel,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            tooltip: l10n.copyTooltip,
                                            onPressed: () => CopyHelper.copy(context, importFeeCtrl.text),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(l10n.docsAndClearanceSection,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                                ),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: requiresAcid,
                                      activeColor: AppTheme.cobalt,
                                      onChanged: (val) => setDialogState(() => requiresAcid = val ?? true),
                                    ),
                                    Text(l10n.requiresAcidCheckbox, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Checkbox(
                                      value: requiresCoo,
                                      activeColor: AppTheme.cobalt,
                                      onChanged: (val) => setDialogState(() => requiresCoo = val ?? false),
                                    ),
                                    Text(l10n.requiresCooCheckbox, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Checkbox(
                                      value: requiresInspection,
                                      activeColor: AppTheme.cobalt,
                                      onChanged: (val) => setDialogState(() => requiresInspection = val ?? false),
                                    ),
                                    Text(l10n.requiresInspectionCheckbox, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: authCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.govAuthorityLabel,
                                    hintText: l10n.govAuthorityHint,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      tooltip: l10n.copyTooltip,
                                      onPressed: () => CopyHelper.copy(context, authCtrl.text),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: priorApprovalCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.priorApprovalsLabel,
                                    hintText: l10n.priorApprovalsHint,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      tooltip: l10n.copyTooltip,
                                      onPressed: () => CopyHelper.copy(context, priorApprovalCtrl.text),
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: notesCtrl,
                                  decoration: InputDecoration(
                                    labelText: l10n.tariffNotesLabel,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      tooltip: l10n.copyTooltip,
                                      onPressed: () => CopyHelper.copy(context, notesCtrl.text),
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => UnsavedChangesGuard.maybePop(ctx, isDirty: isDirty()),
              child: Text(l10n.cancel),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(
                isLoading
                    ? l10n.savingProgress
                    : (activeModeIndex == 0
                        ? l10n.saveAllTariffAndAgreementsBtn
                        : (tariff == null ? l10n.addTariffBtnShort : l10n.saveTariffChangesBtn)),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);

                      String? error;
                      try {
                        if (activeModeIndex == 0) {
                          // Smart text save mode
                          if (rawTextCtrl.text.trim().isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              parseError = l10n.pasteTextFirstError;
                            });
                            return;
                          }

                          // Parse if not parsed yet
                          if (parsedTariffData == null || (parsedTariffData!['hs_code'] as String).isEmpty) {
                            doLocalParse(rawTextCtrl.text, setDialogState);
                          }

                          if (parsedTariffData == null || (parsedTariffData!['hs_code'] as String).isEmpty) {
                            setDialogState(() {
                              isLoading = false;
                              parseError = l10n.cannotExtractHsCodeError;
                            });
                            return;
                          }

                          // Attempt official backend parsing for highest schema fidelity
                          Map<String, dynamic> finalPayload;
                          try {
                            final backendParsed = await ref
                                .read(customsTariffProvider.notifier)
                                .parseSmartNafezaText(rawTextCtrl.text.trim());
                            if (backendParsed != null && backendParsed['tariff_data'] != null) {
                              finalPayload = {
                                'tariff': backendParsed['tariff_data'],
                                'agreements': backendParsed['agreements'] ?? [],
                              };
                            } else {
                              finalPayload = {
                                'tariff': parsedTariffData,
                                'agreements': parsedAgreements,
                              };
                            }
                          } catch (parseEx) {
                            // Fallback to locally parsed preview data
                            finalPayload = {
                              'tariff': parsedTariffData,
                              'agreements': parsedAgreements,
                            };
                          }

                          error = await ref
                              .read(customsTariffProvider.notifier)
                              .saveTariffWithAgreements(finalPayload);
                        } else {
                          // Manual form save mode
                          if (!formKey.currentState!.validate()) {
                            setDialogState(() => isLoading = false);
                            return;
                          }

                          final data = {
                            'hs_code': hsCtrl.text.trim(),
                            'hs_description': descCtrl.text.trim(),
                            'customs_category': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
                            'customs_duty_rate': double.parse(dutyCtrl.text.trim()),
                            'vat_rate': double.parse(vatCtrl.text.trim()),
                            'schedule_tax_rate': double.parse(schedCtrl.text.trim()),
                            'development_fee_rate': double.parse(devCtrl.text.trim()),
                            'import_fee_rate': double.parse(importFeeCtrl.text.trim()),
                            'requires_coo': requiresCoo,
                            'requires_inspection': requiresInspection,
                            'requires_acid': requiresAcid,
                            'regulatory_authority': authCtrl.text.trim().isEmpty ? null : authCtrl.text.trim(),
                            'prior_approval_note': priorApprovalCtrl.text.trim().isEmpty ? null : priorApprovalCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          };

                          if (tariff == null) {
                            error = await ref.read(customsTariffProvider.notifier).createTariff(data);
                          } else {
                            error = await ref.read(customsTariffProvider.notifier).updateTariff(tariff.tariffId, data);
                          }
                        }
                      } catch (e) {
                        error = e.toString();
                      }

                      setDialogState(() => isLoading = false);
                      if (ctx.mounted) {
                        if (error != null) {
                          // Show clear, copyable, structured dialog explaining the exact errors
                          showDialog(
                            context: context,
                            builder: (errCtx) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppTheme.crimson),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.saveFailureTitle,
                                    style: const TextStyle(
                                        color: AppTheme.crimson,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                              content: SizedBox(
                                width: 500,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.saveFailureIntro,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.charcoal),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: SelectableText(
                                          error ?? 'Error',
                                          style: TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color: Colors.red.shade900,
                                              fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.cobalt),
                                  onPressed: () => Navigator.pop(errCtx),
                                  child: Text(l10n.adjustInputsBtn,
                                      style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tariff == null
                                  ? l10n.tariffAddedSuccess
                                  : l10n.tariffUpdatedSuccess),
                              backgroundColor: AppTheme.emerald,
                            ),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  ).then((_) {
      hsCtrl.dispose();
      descCtrl.dispose();
      catCtrl.dispose();
      dutyCtrl.dispose();
      vatCtrl.dispose();
      schedCtrl.dispose();
      devCtrl.dispose();
      importFeeCtrl.dispose();
      authCtrl.dispose();
      priorApprovalCtrl.dispose();
      notesCtrl.dispose();
      rawTextCtrl.dispose();
    });
  }
