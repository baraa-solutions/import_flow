import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/widgets/legal_compliance_banner.dart';
import 'package:frontend/features/import_documentation/widgets/visual_draft_bl_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';

void main() {
  group('Phase 6: PO Final Reconciliation & Certification Models Test', () {
    test('POReconciliationItemModel JSON serialization and variance check', () {
      final item = POReconciliationItemModel(
        poItemId: 10,
        itemCode: 'ITEM-MACH-100',
        description: 'Industrial Air Compressor Unit',
        packageType: 'Carton',
        initialQuantity: 100.0,
        finalQuantity: 105.0,
        initialUnitPrice: 250.0,
        unitPrice: 260.0,
        finalUnitPrice: 260.0,
        initialPackagesCount: 10.0,
        finalPackagesCount: 12.0,
        initialNetWeightKg: 20000.0,
        finalNetWeightKg: 21000.0,
        initialGrossWeightKg: 23500.0,
        finalGrossWeightKg: 24500.0,
        initialCbm: 55.0,
        finalCbm: 58.4,
        variancePercentage: 5.0,
        priceVariancePercentage: 4.0,
        weightVariancePercentage: 4.26,
      );

      final json = item.toJson();
      expect(json['item_code'], 'ITEM-MACH-100');
      expect(json['initial_quantity'], 100.0);
      expect(json['final_quantity'], 105.0);
      expect(json['initial_unit_price'], 250.0);
      expect(json['final_unit_price'], 260.0);
      expect(json['final_packages_count'], 12.0);
      expect(json['variance_percentage'], 5.0);
      expect(json['price_variance_percentage'], 4.0);

      final parsed = POReconciliationItemModel.fromJson(json);
      expect(parsed.description, 'Industrial Air Compressor Unit');
      expect(parsed.unitPrice, 260.0);
      expect(parsed.packageType, 'Carton');
      expect(parsed.finalGrossWeightKg, 24500.0);
    });

    test('POReconciliationItemModel keeps a null package_type empty, not an invented type', () {
      final parsed = POReconciliationItemModel.fromJson({
        'po_item_id': 2,
        'item_code': 'QCR12026802R',
        'description': 'Rubber Shock Absorbers',
        'package_type': null,
        'initial_quantity': 2.0,
        'final_quantity': 2.0,
      });
      expect(parsed.packageType, '');
      expect(parsed.toJson()['package_type'], '');
    });

    test('POReconciliationResultModel serialization and metrics calculation', () {
      final result = POReconciliationResultModel(
        status: 'success',
        message: 'Reconciliation certified',
        importFileId: 1,
        finalInvoiceNumber: 'INV-FINAL-2026-001',
        finalPackingListNumber: 'PL-FINAL-2026-001',
        totalItemsCount: 2,
        totalNetWeightKg: 1000.0,
        totalGrossWeightKg: 1200.0,
        totalCbm: 5.5,
        totalFinalAmount: 7000.0,
        items: [
          POReconciliationItemModel(
            itemCode: 'ITEM-01',
            description: 'Item 1',
            packageType: 'Carton',
            initialQuantity: 50.0,
            finalQuantity: 50.0,
            initialUnitPrice: 100.0,
            unitPrice: 100.0,
            finalUnitPrice: 100.0,
            initialPackagesCount: 5.0,
            finalPackagesCount: 5.0,
            initialNetWeightKg: 500.0,
            finalNetWeightKg: 500.0,
            initialGrossWeightKg: 600.0,
            finalGrossWeightKg: 600.0,
            initialCbm: 2.5,
            finalCbm: 2.5,
          ),
          POReconciliationItemModel(
            itemCode: 'ITEM-02',
            description: 'Item 2',
            packageType: 'Pallet',
            initialQuantity: 10.0,
            finalQuantity: 10.0,
            initialUnitPrice: 200.0,
            unitPrice: 200.0,
            finalUnitPrice: 200.0,
            initialPackagesCount: 2.0,
            finalPackagesCount: 2.0,
            initialNetWeightKg: 500.0,
            finalNetWeightKg: 500.0,
            initialGrossWeightKg: 600.0,
            finalGrossWeightKg: 600.0,
            initialCbm: 3.0,
            finalCbm: 3.0,
          ),
        ],
      );

      final json = result.toJson();
      expect(json['status'], 'success');
      expect(json['final_invoice_number'], 'INV-FINAL-2026-001');

      final parsed = POReconciliationResultModel.fromJson(json);
      expect(parsed.items.length, 2);
      expect(parsed.totalFinalAmount, 7000.0);
    });
  });

  group('Phase 6: Draft B/L Discrepancy Matrix & Review Models Test', () {
    test('DraftBLDiscrepancyItemModel parsing and blocking flags', () {
      final discrepancy = DraftBLDiscrepancyItemModel(
        fieldKey: 'booking_no',
        fieldLabelAr: 'رقم الحجز الملاحي',
        fieldLabelEn: 'Booking Number',
        sourceDocument: 'ShipmentBooking',
        systemValue: 'BK-EGY-9901',
        draftValue: 'BK-EGY-9902',
        matchStatus: 'Mismatch',
        severity: 'BLOCKING',
        details: 'Booking number does not match carrier confirmation',
      );

      final json = discrepancy.toJson();
      expect(json['severity'], 'BLOCKING');
      expect(json['field_key'], 'booking_no');

      final parsed = DraftBLDiscrepancyItemModel.fromJson(json);
      expect(parsed.fieldLabelAr, 'رقم الحجز الملاحي');
      expect(parsed.matchStatus, 'Mismatch');
    });

    test('DraftBLComparisonResultModel serialization and correction letter', () {
      final compResult = DraftBLComparisonResultModel(
        importFileId: 1,
        systemData: {'booking_no': 'BK-001'},
        draftData: {'booking_no': 'BK-002'},
        matrix: [
          DraftBLDiscrepancyItemModel(
            fieldKey: 'booking_no',
            fieldLabelAr: 'رقم الحجز الملاحي',
            fieldLabelEn: 'Booking Number',
            sourceDocument: 'ShipmentBooking',
            systemValue: 'BK-001',
            draftValue: 'BK-002',
            matchStatus: 'Mismatch',
            severity: 'BLOCKING',
            details: 'Mismatch',
          ),
        ],
        hasDiscrepancies: true,
        hasBlockingMismatch: true,
        blockingReasons: ['رقم الحجز غير مطابق'],
        status: 'Correction Requested',
        correctionRequestLetter: 'Dear Mediterranean Shipping Company (MSC),\nPlease rectify Booking No to BK-001.',
      );

      final json = compResult.toJson();
      expect(json['has_blocking_mismatch'], true);
      expect(json['status'], 'Correction Requested');
      expect(json['correction_request_letter'], contains('Dear Mediterranean Shipping Company'));

      final parsed = DraftBLComparisonResultModel.fromJson(json);
      expect(parsed.blockingReasons.length, 1);
      expect(parsed.hasDiscrepancies, true);
    });

    test('DraftBLChecklistItemModel and RevisionReportItemModel serialization and stage transitions', () {
      final checklistItem = DraftBLChecklistItemModel(
        fieldKey: 'vessel_name',
        fieldLabelAr: 'اسم السفينة',
        fieldLabelEn: 'Vessel Name',
        sourceEntity: 'Final Booking',
        systemValue: 'CMA CGM ANTOINE DE SAINT EXUPERY',
        draftValue: 'CMA CGM ANTOINE',
        status: 'Incorrect',
        requiredCorrection: 'Correct Vessel name to full official name',
        reason: 'Typo in carrier draft',
        responsibleParty: 'Shipping Provider',
        isLocked: false,
      );

      final json = checklistItem.toJson();
      expect(json['field_key'], 'vessel_name');
      expect(json['status'], 'Incorrect');
      expect(json['responsible_party'], 'Shipping Provider');

      final parsed = DraftBLChecklistItemModel.fromJson(json);
      expect(parsed.fieldLabelAr, 'اسم السفينة');
      expect(parsed.requiredCorrection, 'Correct Vessel name to full official name');
      expect(parsed.isLocked, false);

      final revReport = RevisionReportItemModel(
        item: 'Vessel Name',
        requiredAction: 'Correct Vessel name to full official name',
        responsible: 'Shipping Provider',
        reason: 'Typo in carrier draft',
      );
      final rJson = revReport.toJson();
      expect(rJson['item'], 'Vessel Name');
      expect(rJson['responsible'], 'Shipping Provider');

      final rParsed = RevisionReportItemModel.fromJson(rJson);
      expect(rParsed.requiredAction, 'Correct Vessel name to full official name');
    });

    test('DraftBLReviewModel session parsing and approval lifecycle with 5-stage engine', () {
      final review = DraftBLReviewModel(
        blReviewId: 1,
        blReviewCode: 'BLR-2026-0001',
        importFileId: 1,
        draftBlNumber: 'MEDU-DRAFT-9901',
        shippingLine: 'MSC',
        stage: 'Stage 4: Dual Approval',
        versionNumber: 2,
        systemDataSnapshot: {},
        draftExtractedData: {},
        comparisonMatrix: [],
        checklistData: [
          DraftBLChecklistItemModel(
            fieldKey: 'vessel_name',
            fieldLabelAr: 'اسم السفينة',
            fieldLabelEn: 'Vessel Name',
            sourceEntity: 'Final Booking',
            systemValue: 'MSC ISABELLA',
            draftValue: 'MSC ISABELLA',
            status: 'Correct',
            isLocked: true,
          ),
        ],
        hasDiscrepancies: false,
        hasBlockingMismatch: false,
        blockingReasons: [],
        importerApprovalStatus: 'Approved',
        importerApprovedBy: 'Kamal Import Officer',
        brokerApprovalStatus: 'Approved',
        brokerApprovedBy: 'Ahmed Customs Broker',
        status: 'FINAL',
        approvedBy: 'Kamal Import Officer & Ahmed Customs Broker',
        isActive: true,
        createdAt: '2026-08-16T12:00:00Z',
      );

      final json = review.toJson();
      expect(json['bl_review_code'], 'BLR-2026-0001');
      expect(json['stage'], 'Stage 4: Dual Approval');
      expect(json['importer_approval_status'], 'Approved');
      expect(json['broker_approval_status'], 'Approved');
      expect(json['version_number'], 2);

      final parsed = DraftBLReviewModel.fromJson(json);
      expect(parsed.approvedBy, 'Kamal Import Officer & Ahmed Customs Broker');
      expect(parsed.checklistData.first.isLocked, true);
      expect(parsed.versionNumber, 2);
    });
  });

  group('Phase 6: Legal Documents & ACID + 30 Days Expiry Compliance Test', () {
    test('LegalDocsExpiryComplianceModel parsing and safety window verification', () {
      final compliance = LegalDocsExpiryComplianceModel(
        importFileId: 1,
        importFileCode: 'IF-2026-001',
        companyName: 'El-Nasr Engineering Co.',
        etaDate: '2026-09-01',
        etaSource: 'FreightBooking',
        safetyWindowDate: '2026-10-01',
        overallComplianceStatus: 'CRITICAL_ACTION_REQUIRED',
        hasCriticalAlerts: true,
        persistentBannerText: '🚨 تنبيه رقابي حرج: بعض المستندات تنتهي قبل وصول الشحنة بـ 30 يوماً',
        alerts: [
          LegalDocAlertItemModel(
            docType: 'البطاقة الاستيرادية (Import Card)',
            docNumber: 'IMP-9901',
            expiryDate: '2026-09-15',
            daysUntilExpiry: 30,
            daysAfterEta: 14,
            isExpired: false,
            isCriticalBreach: true,
            alertMessage: 'تنتهي في 2026-09-15 وهي قبل نافذة الأمان 2026-10-01',
            status: 'CRITICAL_BREACH',
          ),
        ],
      );

      final json = compliance.toJson();
      expect(json['has_critical_alerts'], true);
      expect(json['overall_compliance_status'], 'CRITICAL_ACTION_REQUIRED');

      final parsed = LegalDocsExpiryComplianceModel.fromJson(json);
      expect(parsed.alerts.length, 1);
      expect(parsed.alerts.first.isCriticalBreach, true);
      expect(parsed.etaDate, '2026-09-01');
    });
  });

  group('Phase 6: Widgets & UI Banner Integration Test', () {
    testWidgets('LegalComplianceBanner renders critical alert when breach detected', (WidgetTester tester) async {
      final mockCompliance = LegalDocsExpiryComplianceModel(
        importFileId: 1,
        importFileCode: 'IF-2026-001',
        companyName: 'Al Ahly Import Co.',
        etaDate: '2026-09-01',
        etaSource: 'FreightBooking',
        safetyWindowDate: '2026-10-01',
        overallComplianceStatus: 'CRITICAL_ACTION_REQUIRED',
        hasCriticalAlerts: true,
        persistentBannerText: '🚨 تنبيه رقابي حرج: البطاقة الاستيرادية تنتهي قبل الموعد',
        alerts: [
          LegalDocAlertItemModel(
            docType: 'البطاقة الاستيرادية',
            docNumber: 'IMP-001',
            expiryDate: '2026-09-15',
            daysUntilExpiry: 30,
            daysAfterEta: 14,
            isExpired: false,
            isCriticalBreach: true,
            alertMessage: 'تنتهي قبل نافذة الأمان',
            status: 'CRITICAL_BREACH',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legalComplianceFamilyProvider(1).overrideWith(
              (ref) => Future.value(mockCompliance),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LegalComplianceBanner(importFileId: 1),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('تحذير قانوني وإجرائي حرج'), findsOneWidget);
      expect(find.textContaining('البطاقة الاستيرادية: تنتهي في 2026-09-15'), findsOneWidget);
    });

    testWidgets('VisualDraftBLSheet renders authentic B/L document layout with ACID block', (WidgetTester tester) async {
      final systemData = {
        'draft_bl_number': 'MEDUAA123456',
        'booking_no': 'BK-MSC-99',
        'shipper': 'G.I. Industrial Holding S.p.A.',
        'consignee': 'ECO ASSOCIATES for Trading and Contracting',
        'notify_party': 'ECO ASSOCIATES for Trading and Contracting',
        'vessel_name': 'MSC PORTO III',
        'voyage_number': 'AB635A',
        'pol': 'Genoa Port',
        'pod': 'El Dekheila Port',
        'acid_number': '7595528271019210013',
        'importer_tax_id': '759552827',
        'shipper_reg_id': 'IT000458921',
        'packages_count': 31,
        'goods_description': 'AIR CONDITIONING UNITS & CHILLERS',
        'total_gross_weight_kg': 20030.0,
        'cbm': 65.4,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualDraftBLSheet(
                systemData: systemData,
                draftData: const {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('BILL OF LADING (DRAFT)'), findsOneWidget);
      expect(find.textContaining('CONSIGNEE:'), findsOneWidget);
      expect(find.textContaining('NOTIFY PARTY:'), findsOneWidget);
      expect(find.textContaining('7595528271019210013'), findsOneWidget);
      expect(find.textContaining('G.I. Industrial Holding S.p.A.'), findsOneWidget);
      expect(find.textContaining('تنزيل PDF'), findsOneWidget);
      expect(find.textContaining('تنزيل Excel'), findsOneWidget);
    });
  });
}
