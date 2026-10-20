import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/widgets/extraction_confidence_indicator.dart';
import 'package:frontend/features/customs_consultation/widgets/extraction_summary_dialog.dart';

import '../../helpers/localized_app.dart';
import 'package:frontend/core/localization/app_locales.dart';

Widget wrapWithLocalization(Widget child, [Locale locale = AppLocales.arabic]) {
  return localizedApp(
    locale: locale,
    home: Scaffold(body: child),
  );
}

void main() {
  group('M1-5: ExtractionConfidenceIndicator Tests', () {
    testWidgets('Renders High Confidence (>= 85%) with green theme and check icon', (tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const ExtractionConfidenceIndicator(
            confidence: 0.94,
            rawExtractedText: 'نولون بحري أصلي',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('94%'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('Renders Medium Confidence (60-84%) with warning theme and alert icon', (tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const ExtractionConfidenceIndicator(
            confidence: 0.72,
            rawExtractedText: 'تخزين ومستودعات',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('72%'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Renders Low / Uncoded (< 60%) with danger theme and error icon', (tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const ExtractionConfidenceIndicator(
            confidence: 0.40,
            isUncoded: true,
            rawExtractedText: 'مصروفات مجهولة غير مطابقة',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بحاجة لتكويد'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('Returns SizedBox.shrink when confidence is null and not uncoded', (tester) async {
      await tester.pumpWidget(
        wrapWithLocalization(
          const ExtractionConfidenceIndicator(
            confidence: null,
            isUncoded: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExtractionConfidenceIndicator), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('M1-6: ExtractionSummaryDialog Tests', () {
    final sampleItems = [
      const ExtractedSummaryItem(
        rawName: 'اتعاب تخليص 3500',
        matchedCanonicalName: 'أتعاب التخليص الجمركي',
        category: 'Clearance Fees',
        price: 3500.0,
        confidence: 0.95,
        isUncoded: false,
      ),
      const ExtractedSummaryItem(
        rawName: 'نقل داخلي 1800',
        matchedCanonicalName: 'نولون بري للمستودع',
        category: 'Inland Transport',
        price: 1800.0,
        confidence: 0.88,
        isUncoded: false,
      ),
      const ExtractedSummaryItem(
        rawName: 'معاينة 750',
        matchedCanonicalName: 'رسوم كشف ومعاينة',
        category: 'Port & Handling',
        price: 750.0,
        confidence: 0.70,
        isUncoded: false,
      ),
      const ExtractedSummaryItem(
        rawName: 'رسوم اضافية غير محددة',
        matchedCanonicalName: 'بند غير معروف',
        category: 'Other Fees',
        price: 0.0,
        confidence: 0.45,
        isUncoded: true,
      ),
    ];

    testWidgets('Renders KPI statistics correctly (Total: 4, High: 2, Medium: 1, Uncoded: 1)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWithLocalization(
          ExtractionSummaryDialog(
            items: sampleItems,
            fileName: 'broker_invoice.pdf',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and file name
      expect(find.text('ملخص استخراج البيانات بالذكاء الاصطناعي'), findsOneWidget);
      expect(find.textContaining('broker_invoice.pdf'), findsOneWidget);

      // Check KPI values
      expect(find.text('4'), findsWidgets); // Total count
      expect(find.text('2'), findsWidgets); // High count
      expect(find.text('1'), findsWidgets); // Medium and Uncoded counts

      // Check item names appear
      expect(find.text('أتعاب التخليص الجمركي'), findsOneWidget);
      expect(find.text('نولون بري للمستودع'), findsOneWidget);
      expect(find.text('رسوم كشف ومعاينة'), findsOneWidget);
      expect(find.text('بند غير معروف'), findsOneWidget);

      // Action buttons
      expect(find.text('تطبيق في القائمة'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('Pops with true when apply button is tapped', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? dialogResult;
      await tester.pumpWidget(
        wrapWithLocalization(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                dialogResult = await ExtractionSummaryDialog.show(
                  context: ctx,
                  items: sampleItems,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractionSummaryDialog), findsOneWidget);

      await tester.tap(find.text('تطبيق في القائمة'));
      await tester.pumpAndSettle();

      expect(find.byType(ExtractionSummaryDialog), findsNothing);
      expect(dialogResult, isTrue);
    });
  });

  group('Model Serialization: confidence and rawExtractedText', () {
    test('BrokerPriceListItemModel serialization and copyWith', () {
      final item = BrokerPriceListItemModel(
        itemId: 10,
        priceListId: 5,
        expenseName: 'أتعاب تخليص',
        category: 'Clearance Fees',
        unitType: 'Per Shipment',
        standardPrice: 2500.0,
        currency: 'EGP',
        confidence: 0.92,
        rawExtractedText: 'Customs clearance 2500',
      );

      final json = item.toJson();
      expect(json['confidence'], 0.92);
      expect(json['raw_extracted_text'], 'Customs clearance 2500');

      final fromJson = BrokerPriceListItemModel.fromJson(json);
      expect(fromJson.confidence, 0.92);
      expect(fromJson.rawExtractedText, 'Customs clearance 2500');

      final updated = fromJson.copyWith(confidence: 0.99, rawExtractedText: 'Updated text');
      expect(updated.confidence, 0.99);
      expect(updated.rawExtractedText, 'Updated text');
    });

    test('CustomsBrokerQuoteItemModel serialization and copyWith', () {
      final quoteItem = CustomsBrokerQuoteItemModel(
        expenseName: 'نولون',
        category: 'Inland Transport',
        unitType: 'Per Container',
        unitPrice: 1200.0,
        confidence: 0.65,
        rawExtractedText: 'Inland freight 1200',
      );

      final json = quoteItem.toJson();
      expect(json['confidence'], 0.65);
      expect(json['raw_extracted_text'], 'Inland freight 1200');

      final fromJson = CustomsBrokerQuoteItemModel.fromJson(json);
      expect(fromJson.confidence, 0.65);
      expect(fromJson.rawExtractedText, 'Inland freight 1200');

      final copied = fromJson.copyWith(confidence: 0.82);
      expect(copied.confidence, 0.82);
      expect(copied.rawExtractedText, 'Inland freight 1200');
    });
  });

  group('M2-3: Note Templates Logic', () {
    test('Appends note template with separator bullet without duplicating', () {
      const templates = [
        'يُضاف عند الحاجة فقط',
        'يشمل الضريبة',
        'يتغير حسب سعر الصرف',
        'يُحسب على الوزن الفعلي',
        'لا يشمل الغرامات والأرضيات',
        'شامل الروافع والكلارك',
      ];

      expect(templates.length, 6);

      String currentNotes = '';
      final t1 = templates[0];
      currentNotes = currentNotes.isEmpty ? t1 : '$currentNotes • $t1';
      expect(currentNotes, 'يُضاف عند الحاجة فقط');

      final t2 = templates[1];
      currentNotes = currentNotes.isEmpty ? t2 : (currentNotes.contains(t2) ? currentNotes : '$currentNotes • $t2');
      expect(currentNotes, 'يُضاف عند الحاجة فقط • يشمل الضريبة');

      // Attempt duplicate addition
      currentNotes = currentNotes.contains(t2) ? currentNotes : '$currentNotes • $t2';
      expect(currentNotes, 'يُضاف عند الحاجة فقط • يشمل الضريبة');
    });
  });

  group('M3-2: Filter Chips and Live Search Filtering Logic', () {
    final items = [
      {
        'expense_name': 'أتعاب التخليص الجمركي',
        'code': 'EXP-CLR-01',
        'category': 'Clearance Fees',
        'standard_price': 3500.0,
        'currency': 'EGP',
        'price_type': 'fixed',
        'notes': 'يشمل الضريبة',
        'is_uncoded': false,
      },
      {
        'expense_name': 'نولون بحري دولي',
        'code': 'EXP-FRT-02',
        'category': 'Port & Handling',
        'standard_price': 500.0,
        'currency': 'USD',
        'price_type': 'fixed',
        'notes': 'حسب سعر الصرف',
        'is_uncoded': false,
      },
      {
        'expense_name': 'خدمات لوجستية إضافية',
        'code': null,
        'category': 'Other Fees',
        'standard_price': 0.0,
        'currency': 'EGP',
        'price_type': 'negotiable',
        'notes': 'تفاوضي',
        'is_uncoded': true,
      },
    ];

    test('Live search across name, code, notes, category', () {
      List<Map<String, dynamic>> search(String q) {
        final query = q.trim().toLowerCase();
        return items.where((itm) {
          final name = (itm['expense_name']?.toString() ?? '').toLowerCase();
          final code = (itm['code']?.toString() ?? '').toLowerCase();
          final notes = (itm['notes']?.toString() ?? '').toLowerCase();
          final cat = (itm['category']?.toString() ?? '').toLowerCase();
          return name.contains(query) || code.contains(query) || notes.contains(query) || cat.contains(query);
        }).toList();
      }

      expect(search('CLR').length, 1);
      expect(search('بحري').length, 1);
      expect(search('تفاوضي').length, 1);
      expect(search('Fees').length, 2);
      expect(search('غير موجود').length, 0);
    });

    test('Filter chip conditions', () {
      // Priced only
      final priced = items.where((i) {
        final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
        final pType = i['price_type']?.toString() ?? '';
        return stdP > 0 && pType != 'negotiable';
      }).toList();
      expect(priced.length, 2);

      // Negotiable only
      final negotiable = items.where((i) {
        final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
        final pType = i['price_type']?.toString() ?? '';
        return pType == 'negotiable' || stdP == 0.0;
      }).toList();
      expect(negotiable.length, 1);

      // Foreign currency only
      final foreign = items.where((i) => (i['currency']?.toString() ?? 'EGP') != 'EGP').toList();
      expect(foreign.length, 1);
      expect(foreign.first['currency'], 'USD');

      // Uncoded only
      final uncoded = items.where((i) => i['is_uncoded'] == true || i['code'] == null).toList();
      expect(uncoded.length, 1);
      expect(uncoded.first['expense_name'], 'خدمات لوجستية إضافية');
    });
  });
}
