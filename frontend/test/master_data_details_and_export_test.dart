import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/master_data_export_service.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/widgets/import_company_details_dialog.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/widgets/supplier_details_dialog.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/widgets/partner_details_dialog.dart';
import 'package:frontend/features/logistics_invoices/models/logistics_invoice_models.dart';
import 'package:frontend/features/logistics_invoices/providers/logistics_invoices_provider.dart';
import 'package:frontend/features/logistics_invoices/repositories/logistics_invoices_repository.dart';
import 'package:frontend/features/logistics_invoices/widgets/invoice_form_dialog.dart';

class _FakeLogisticsInvoicesRepository extends LogisticsInvoicesRepository {
  _FakeLogisticsInvoicesRepository() : super(Dio());

  @override
  Future<PrefillLinesModel> getPrefillLines(int shipmentId, String partnerType) async {
    return PrefillLinesModel(
      shipmentId: shipmentId,
      partnerType: partnerType,
      currency: 'USD',
      exchangeRate: 48.5,
      lines: const [],
    );
  }

  @override
  Future<PartnerBalanceCardModel> getPartnerBalanceCard(int partnerId) async {
    return PartnerBalanceCardModel(
      partnerId: partnerId,
      partnerName: 'National Bank of Egypt (NBE)',
      partnerType: 'bank',
      totalInvoicedEgp: 0.0,
      totalPaidEgp: 0.0,
      balanceDueEgp: 0.0,
      openInvoicesCount: 0,
      aging: AgingBucketModel(),
    );
  }
}

void main() {
  group('MasterDataExportService WhatsApp & Email String Generators', () {
    final sampleCompany = ImportCompanyModel(
      companyId: 1,
      importerName: 'Al-Amal Import & Export Co.',
      address: '10th of Ramadan City, Cairo',
      country: 'Egypt',
      importerId: 'IMP-123456',
      importerIdExpiry: DateTime(2027, 12, 31),
      vatId: 'TAX-789-456-123',
      vatIdExpiry: DateTime(2027, 12, 31),
      registrationNumber: 'CR-998877',
      registrationExpiry: DateTime(2027, 12, 31),
      phone: '+201001234567',
      email: 'info@alamal.eg',
      notes: 'Leading importer of ceramic goods',
      isActive: true,
    );

    final sampleSupplier = SupplierModel(
      supplierId: 10,
      supplierCode: 'SUP-000010',
      companyName: 'Foshan Ceramics Ltd',
      supplierType: 'Manufacturer',
      registrationType: 'Factory Registration',
      foreignExporterId: 'FE-CN-9988',
      cargoxPlatformId: 'CX-9988-ABC',
      foreignExporterCountry: 'China',
      foreignExporterCountryCode: 'CN',
      address: 'Industrial Park, Foshan, Guangdong',
      phone: '+86 757 8888 9999',
      email: 'sales@foshanceramics.cn',
      bankName: 'Bank of China',
      swiftCode: 'BKCHCNBJ',
      accountNumber: '6228480011223344',
      iban: 'CN99BKCH6228480011223344',
      brands: 'FOSHAN PRIME, CERAMIC PRO',
      notes: 'Top tier Chinese ceramic factory',
      isActive: true,
      hasIso: true,
      registeredDecree43: true,
      whiteListRegistered: true,
    );

    final samplePartner = PartnerModel(
      providerId: 25,
      partnerCode: 'PRT-000025',
      partnerName: 'Maersk Line Egypt',
      partnerType: 'Shipping Line, Logistics',
      country: 'Egypt',
      scacCode: 'MAEU',
      swiftCode: 'MAERUS33',
      contactPerson: 'Eng. Tamer Adel',
      phone: '+201223344556',
      email: 'egypt@maersk.com',
      address: 'Port Said Port Logistics Zone',
      paymentType: 'Credit',
      creditLimit: 500000.0,
      rating: 4.8,
      commercialRegister: 'CR-776655',
      taxId: 'TX-332211',
      isActive: true,
    );

    test('generateImporterWhatsAppText contains essential registration & name fields', () {
      final text = MasterDataExportService.generateImporterWhatsAppText(sampleCompany);
      expect(text, contains('Al-Amal Import & Export Co.'));
      expect(text, contains('IMP-123456'));
      expect(text, contains('TAX-789-456-123'));
      expect(text, contains('CR-998877'));
      expect(text, contains('+201001234567'));
    });

    test('generateImporterEmailSubject and Body produce valid formal texts', () {
      final subject = MasterDataExportService.generateImporterEmailSubject(sampleCompany);
      final body = MasterDataExportService.generateImporterEmailBody(sampleCompany);
      expect(subject, contains('Al-Amal Import & Export Co.'));
      expect(subject, contains('IMP-123456'));
      expect(body, contains('IMP-123456'));
      expect(body, contains('info@alamal.eg'));
    });

    test('generateSupplierWhatsAppText contains supplier code, CargoX, and bank SWIFT', () {
      final text = MasterDataExportService.generateSupplierWhatsAppText(sampleSupplier);
      expect(text, contains('SUP-000010'));
      expect(text, contains('Foshan Ceramics Ltd'));
      expect(text, contains('FE-CN-9988'));
      expect(text, contains('CX-9988-ABC'));
      expect(text, contains('BKCHCNBJ'));
    });

    test('generateSupplierEmail produces structured exporter details', () {
      final subject = MasterDataExportService.generateSupplierEmailSubject(sampleSupplier);
      final body = MasterDataExportService.generateSupplierEmailBody(sampleSupplier);
      expect(subject, contains('SUP-000010'));
      expect(body, contains('BKCHCNBJ'));
      expect(body, contains('Foshan Ceramics Ltd'));
      expect(body, contains('sales@foshanceramics.cn'));
    });

    test('generatePartnerWhatsAppText contains SCAC, SWIFT, and contact person', () {
      final text = MasterDataExportService.generatePartnerWhatsAppText(samplePartner);
      expect(text, contains('PRT-000025'));
      expect(text, contains('Maersk Line Egypt'));
      expect(text, contains('MAEU'));
      expect(text, contains('MAERUS33'));
      expect(text, contains('Eng. Tamer Adel'));
    });
  });

  group('Master Data Details Modal Dialog Widgets Rendering', () {
    final testCompany = ImportCompanyModel(
      companyId: 1,
      importerName: 'Delta Trading & Import',
      address: 'Nasr City, Cairo',
      country: 'Egypt',
      importerId: 'IMP-778899',
      importerIdExpiry: DateTime.now().add(const Duration(days: 90)),
      vatId: 'TAX-112233',
      vatIdExpiry: DateTime.now().add(const Duration(days: 90)),
      registrationNumber: 'CR-445566',
      registrationExpiry: DateTime.now().add(const Duration(days: 90)),
      phone: '+201009988776',
      email: 'delta@trading.eg',
      isActive: true,
    );

    testWidgets('ImportCompanyDetailsDialog renders company name, badges, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportCompanyDetailsDialog(company: testCompany),
          ),
        ),
      );

      expect(find.text('Delta Trading & Import'), findsOneWidget);
      expect(find.text('IMP-778899'), findsOneWidget);
      expect(find.text('TAX-112233'), findsOneWidget);
      expect(find.text('CR-445566'), findsOneWidget);
      expect(find.text('طباعة وحفظ المستند 🖨️'), findsOneWidget);
      expect(find.text('تصدير جدول بيانات 📊'), findsOneWidget);
      expect(find.text('مشاركة واتساب 💬'), findsOneWidget);
      expect(find.text('مشاركة بريد إلكتروني ✉️'), findsOneWidget);
    });

    final testSupplier = SupplierModel(
      supplierId: 2,
      supplierCode: 'SUP-000002',
      companyName: 'Bologna Tiles SPA',
      supplierType: 'Manufacturer',
      registrationType: 'Factory Registration',
      foreignExporterId: 'FE-IT-5544',
      cargoxPlatformId: 'CX-IT-5544',
      foreignExporterCountry: 'Italy',
      foreignExporterCountryCode: 'IT',
      address: 'Via Emilia 120, Bologna',
      phone: '+39 051 123456',
      email: 'export@bolognatiles.it',
      bankName: 'Intesa Sanpaolo',
      swiftCode: 'BCITITMM',
      accountNumber: 'IT99000112233',
      iban: 'IT99BCIT0001122334455',
      brands: 'BOLOGNA LUXURY',
      isActive: true,
      hasIso: true,
      registeredDecree43: true,
    );

    testWidgets('SupplierDetailsDialog renders supplier code, country, bank, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupplierDetailsDialog(supplier: testSupplier),
          ),
        ),
      );

      expect(find.text('SUP-000002'), findsOneWidget);
      expect(find.text('Bologna Tiles SPA'), findsOneWidget);
      expect(find.text('FE-IT-5544'), findsOneWidget);
      expect(find.text('BCITITMM'), findsOneWidget);
      expect(find.text('Intesa Sanpaolo'), findsOneWidget);
      expect(find.text('طباعة وحفظ المستند 🖨️'), findsOneWidget);
      expect(find.text('تصدير جدول بيانات 📊'), findsOneWidget);
      expect(find.text('مشاركة واتساب 💬'), findsOneWidget);
      expect(find.text('مشاركة بريد إلكتروني ✉️'), findsOneWidget);
    });

    final testPartner = PartnerModel(
      providerId: 5,
      partnerCode: 'PRT-000005',
      partnerName: 'National Bank of Egypt (NBE)',
      partnerType: 'Bank',
      country: 'Egypt',
      swiftCode: 'NBEGEGCX',
      contactPerson: 'Mr. Sherif Mansour',
      phone: '+202 19623',
      email: 'trade@nbe.com.eg',
      paymentType: 'Prepaid',
      creditLimit: 0.0,
      isActive: true,
    );

    testWidgets('PartnerDetailsDialog renders partner name, code, SWIFT, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PartnerDetailsDialog(partner: testPartner),
          ),
        ),
      );

      expect(find.text('PRT-000005'), findsOneWidget);
      expect(find.text('National Bank of Egypt (NBE)'), findsOneWidget);
      expect(find.text('NBEGEGCX'), findsOneWidget);
      expect(find.text('Mr. Sherif Mansour'), findsOneWidget);
      expect(find.text('طباعة وحفظ المستند 🖨️'), findsOneWidget);
      expect(find.text('تصدير جدول بيانات 📊'), findsOneWidget);
      expect(find.text('مشاركة واتساب 💬'), findsOneWidget);
      expect(find.text('مشاركة بريد إلكتروني ✉️'), findsOneWidget);
      expect(find.text('كشف حساب 📑'), findsOneWidget);
    });

    testWidgets('InvoiceFormDialog initializes cleanly with initialPartnerId & initialPartnerName without LateInitializationError', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logisticsInvoicesRepositoryProvider.overrideWithValue(_FakeLogisticsInvoicesRepository()),
            partnerBalanceCardProvider.overrideWith((ref, id) async => PartnerBalanceCardModel(
              partnerId: id,
              partnerName: 'National Bank of Egypt (NBE)',
              partnerType: 'bank',
              totalInvoicedEgp: 0.0,
              totalPaidEgp: 0.0,
              balanceDueEgp: 0.0,
              openInvoicesCount: 0,
              aging: AgingBucketModel(),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InvoiceFormDialog(
                defaultPartnerType: 'freight',
                initialPartnerId: 5,
                initialPartnerName: 'National Bank of Egypt (NBE)',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('National Bank of Egypt (NBE)'), findsWidgets);
      expect(find.byType(InvoiceFormDialog), findsOneWidget);
    });

    testWidgets('SupplierDetailsDialog does not contain bilingual composite header or (أوروبا) in Arabic mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('ar'),
            child: Scaffold(
              body: SupplierDetailsDialog(supplier: testSupplier),
            ),
          ),
        ),
      );

      // Must find clean Arabic header
      expect(find.text('شهادات العلامة التجارية والجودة'), findsOneWidget);
      // Must NOT find bilingual parenthesis strings
      expect(find.text('شهادات العلامة التجارية والجودة (Trademark Certificates)'), findsNothing);
      expect(find.text('EUIPO (أوروبا)'), findsNothing);
      expect(find.text('مكتب الملكية الفكرية الأوروبي (EUIPO)'), findsOneWidget);
    });

    testWidgets('ImportCompanyDetailsDialog respects English mode without Arabic text in email labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: Scaffold(
              body: ImportCompanyDetailsDialog(company: testCompany),
            ),
          ),
        ),
      );

      // Must find clean English labels
      expect(find.text('Primary Email'), findsOneWidget);
      expect(find.text('Secondary Email'), findsOneWidget);
      expect(find.text('البريد الأساسي'), findsNothing);
      expect(find.text('البريد الثانوي'), findsNothing);
      expect(find.text('EUIPO'), findsOneWidget);
      expect(find.text('EUIPO (أوروبا)'), findsNothing);
    });
  });
}
