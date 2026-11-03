import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

void main() {
  group('Financial Approvals & Budgets Localization & Anti-Stacked Tests (Screen 8)', () {
    test('Arabic AppLocalizationsAr returns pure Arabic for Financial Approvals', () {
      const lAr = AppLocalizationsAr();

      // Screen 8 Tabs & Titles
      expect(lAr.financialApprovalsTitle, equals('الموافقات المالية وإدارة الميزانية'));
      expect(lAr.paymentRequestsTab, equals('طلبات السداد المالي للمورد'));
      expect(lAr.importBudgetApprovalTab, equals('اعتماد الميزانية الاستيرادية'));
      expect(lAr.savedBudgetsRegistryTab, equals('سجل الميزانيات المعتمدة'));
      expect(lAr.paymentRequestsRegistryTab, equals('سجل طلبات السداد والتحويلات'));
      expect(lAr.swiftReconciliationTab, equals('استخراج ومطابقة إشعار التحويل البنكي السويفت'));

      // Payment Request Form
      expect(lAr.createPaymentRequestTitle, equals('إصدار طلب سداد وتحويل مالي للمورد'));
      expect(lAr.editPaymentRequestTitle, equals('تعديل بيانات طلب السداد الحالي'));
      expect(lAr.activeEditModeBanner, equals('وضع التعديل النشط'));
      expect(lAr.selectSupplierFromMasterData, equals('اختر المورد من البيانات المرجعية'));
      expect(lAr.beneficiarySupplierLabel, equals('المورد المستفيد'));
      expect(lAr.paymentTypeLabel, equals('طريقة / نوع السداد'));
      expect(lAr.requestedAmountLabel, equals('المبلغ المطلوب بالعملة'));
      expect(lAr.beneficiaryBankDetails, equals('بيانات التحويل البنكي للمورد المستفيد'));
      expect(lAr.bankNameLabel, equals('اسم بنك المورد'));
      expect(lAr.swiftCodeLabel, equals('كود السويفت'));
      expect(lAr.ibanAccountLabel, equals('رقم الحساب / الآيبان'));
      expect(lAr.linkedPurchaseOrdersTitle, equals('أوامر الشراء المرتبطة'));
      expect(lAr.paymentNotesLabel, equals('ملاحظات طلب السداد'));
      expect(lAr.issuePaymentRequestButton, equals('إصدار طلب السداد للإدارة المالية'));
      expect(lAr.savePaymentChangesButton, equals('حفظ تعديلات طلب السداد'));

      // Budget Setup & Multi-Currency Summary
      expect(lAr.importBudgetSetupTitle, equals('اعتماد ميزانية ملف الاستيراد الشاملة'));
      expect(lAr.budgetTitleLabel, equals('عنوان الميزانية الاستيرادية'));
      expect(lAr.estimatedInvoiceValue, equals('قيمة الفاتورة المبدئية'));
      expect(lAr.estimatedFreightCost, equals('تكلفة النولون المقدرة'));
      expect(lAr.customsAndVatEstimate, equals('الضرائب والجمارك والـ VAT'));
      expect(lAr.clearanceAndTransportEstimate, equals('أتعاب التخليص والنقل'));
      expect(lAr.budgetApprovalNotes, equals('ملاحظات وتوجيهات اعتماد الميزانية'));
      expect(lAr.approveAndCertifyBudget, equals('التصديق واعتماد الميزانية'));
      expect(lAr.saveBudgetChanges, equals('حفظ تعديلات الميزانية'));
      expect(lAr.totalBudgetEgp, equals('إجمالي الميزانية الاستيرادية الكلية المعتمدة'));
      expect(lAr.consolidatedBudgetSummary, equals('تقرير توزيع بنود الميزانية حسب العملات'));

      // Saved Budgets Metrics
      expect(lAr.totalBudgetsMetric, equals('إجمالي الميزانيات'));
      expect(lAr.approvedBudgetsMetric, equals('ميزانيات معتمدة'));
      expect(lAr.pendingBudgetsMetric, equals('قيد المراجعة / مسودة'));
      expect(lAr.totalValueEgpMetric, equals('إجمالي القيمة التقديرية'));
      expect(lAr.searchBudgetsHint, equals('البحث بكود الميزانية أو العنوان أو كود الشحنة...'));
      expect(lAr.searchPaymentsHint, equals('البحث بكود الطلب أو اسم المورد أو رقم الملف أو العنوان...'));
      expect(lAr.paymentRequestsLogTitle, equals('سجل العمليات والتحويلات المالية للموردين'));
      expect(lAr.noMatchingPayments, equals('لا توجد طلبات سداد مالي مطابقة لخيارات البحث والتصفية.'));
      expect(lAr.noMatchingBudgets, equals('لا توجد اعتمادات ميزانية مطابقة لمعايير البحث.'));

      // SWIFT Extractor & Reconciliation
      expect(lAr.swiftExtractorTitle, equals('استخراج ومطابقة إشعار التحويل البنكي السويفت'));
      expect(lAr.swiftUploadDocument, equals('رفع مستند السويفت'));
      expect(lAr.swiftPasteText, equals('لصق نص رسالة السويفت'));
      expect(lAr.swiftMatchedSuccess, equals('تمت المطابقة مع طلب السداد بنجاح'));
      expect(lAr.swiftExecuteReconciliation, equals('تنفيذ المطابقة والاعتماد المالي'));

      // Anti-stacked verification: Check that strings do not contain stacked English text
      expect(lAr.financialApprovalsTitle.contains('Financial Approvals'), isFalse);
      expect(lAr.paymentRequestsTab.contains('Payment Request Mode'), isFalse);
      expect(lAr.importBudgetSetupTitle.contains('Import Budget Approval'), isFalse);
      expect(lAr.consolidatedBudgetSummary.contains('Multi-Currency Budget Allocation'), isFalse);
      expect(lAr.totalBudgetEgp.contains('Total Approved Budget'), isFalse);
      expect(lAr.swiftExtractorTitle.contains('Smart AI SWIFT MT103 Extractor'), isFalse);
      expect(lAr.swiftReconciliationTab.contains('MT103'), isFalse);
      expect(lAr.swiftExtractorTitle.contains('MT103'), isFalse);
    });

    test('English AppLocalizationsEn returns pure English for Financial Approvals', () {
      const lEn = AppLocalizationsEn();

      // Screen 8 Tabs & Titles
      expect(lEn.financialApprovalsTitle, equals('Financial Approvals & Budget Management'));
      expect(lEn.paymentRequestsTab, equals('Supplier Payment Requests'));
      expect(lEn.importBudgetApprovalTab, equals('Import Budget Approval'));
      expect(lEn.savedBudgetsRegistryTab, equals('Saved Budgets Registry'));
      expect(lEn.paymentRequestsRegistryTab, equals('Payment Requests Log'));
      expect(lEn.swiftReconciliationTab, equals('SWIFT MT103 Reconciliation'));

      // Payment Request Form
      expect(lEn.createPaymentRequestTitle, equals('Issue Supplier Payment Request'));
      expect(lEn.editPaymentRequestTitle, equals('Edit Payment Request'));
      expect(lEn.activeEditModeBanner, equals('Active Edit Mode'));
      expect(lEn.selectSupplierFromMasterData, equals('Select Supplier from Master Data'));
      expect(lEn.beneficiarySupplierLabel, equals('Beneficiary Supplier'));
      expect(lEn.paymentTypeLabel, equals('Payment Type / Terms'));
      expect(lEn.requestedAmountLabel, equals('Requested Amount'));
      expect(lEn.beneficiaryBankDetails, equals('Beneficiary Bank Details'));
      expect(lEn.bankNameLabel, equals('Bank Name'));
      expect(lEn.swiftCodeLabel, equals('SWIFT Code'));
      expect(lEn.ibanAccountLabel, equals('IBAN / Account Number'));
      expect(lEn.linkedPurchaseOrdersTitle, equals('Linked Purchase Orders'));
      expect(lEn.paymentNotesLabel, equals('Payment Request Notes'));
      expect(lEn.issuePaymentRequestButton, equals('Issue Payment Request to Finance'));
      expect(lEn.savePaymentChangesButton, equals('Save Payment Request Changes'));

      // Budget Setup & Multi-Currency Summary
      expect(lEn.importBudgetSetupTitle, equals('Import File Comprehensive Budget Approval'));
      expect(lEn.budgetTitleLabel, equals('Budget Title'));
      expect(lEn.estimatedInvoiceValue, equals('Estimated Invoice Value'));
      expect(lEn.estimatedFreightCost, equals('Estimated Freight Cost'));
      expect(lEn.customsAndVatEstimate, equals('Customs & VAT Estimate'));
      expect(lEn.clearanceAndTransportEstimate, equals('Clearance & Inland Transport'));
      expect(lEn.budgetApprovalNotes, equals('Budget Approval Instructions & Notes'));
      expect(lEn.approveAndCertifyBudget, equals('Approve & Certify Budget'));
      expect(lEn.saveBudgetChanges, equals('Save Budget Changes'));
      expect(lEn.totalBudgetEgp, equals('Total Approved Budget'));
      expect(lEn.consolidatedBudgetSummary, equals('Multi-Currency Budget Allocation Report'));

      // Saved Budgets Metrics
      expect(lEn.totalBudgetsMetric, equals('Total Budgets'));
      expect(lEn.approvedBudgetsMetric, equals('Approved Budgets'));
      expect(lEn.pendingBudgetsMetric, equals('Pending / Draft'));
      expect(lEn.totalValueEgpMetric, equals('Total Value'));
      expect(lEn.searchBudgetsHint, equals('Search by budget code, title, or shipment...'));
      expect(lEn.searchPaymentsHint, equals('Search by request code, supplier, or file...'));
      expect(lEn.paymentRequestsLogTitle, equals('Supplier Payments & Transfers Registry'));
      expect(lEn.noMatchingPayments, equals('No payment requests match search and filters.'));
      expect(lEn.noMatchingBudgets, equals('No budgets match search and filters.'));

      // SWIFT Extractor & Reconciliation
      expect(lEn.swiftExtractorTitle, equals('SWIFT MT103 Bank Transfer Extractor & Matcher'));
      expect(lEn.swiftUploadDocument, equals('Upload SWIFT Document'));
      expect(lEn.swiftPasteText, equals('Paste SWIFT Raw Text'));
      expect(lEn.swiftMatchedSuccess, equals('Matched with Payment Request Successfully'));
      expect(lEn.swiftExecuteReconciliation, equals('Execute Financial Reconciliation'));

      // Anti-stacked verification: Check that strings do not contain stacked Arabic text
      expect(lEn.financialApprovalsTitle.contains('الاعتمادات والموافقات المالية'), isFalse);
      expect(lEn.paymentRequestsTab.contains('إصدار طلب سداد مالي'), isFalse);
      expect(lEn.importBudgetSetupTitle.contains('اعتماد ميزانية'), isFalse);
      expect(lEn.consolidatedBudgetSummary.contains('تقرير توزيع بنود'), isFalse);
      expect(lEn.totalBudgetEgp.contains('إجمالي الميزانية'), isFalse);
      expect(lEn.swiftExtractorTitle.contains('استخراج ومطابقة'), isFalse);
    });

    test('SWIFT Reconciliation labels are verified for both languages without mixing', () {
      const lAr = AppLocalizationsAr();
      const lEn = AppLocalizationsEn();

      expect(lAr.swiftExtractorTitle, isNotEmpty);
      expect(lEn.swiftExtractorTitle, isNotEmpty);
      expect(lAr.swiftCodeLabel, equals('كود السويفت'));
      expect(lEn.swiftCodeLabel, equals('SWIFT Code'));
    });

    test('New Screen 8 Dialogs, Duplicate Warnings & Sharing keys are verified', () {
      const lAr = AppLocalizationsAr();
      const lEn = AppLocalizationsEn();

      // Duplicate detection
      expect(lAr.duplicatePaymentRequestTitle, equals('طلب سداد مالي محفوظ مسبقاً'));
      expect(lEn.duplicatePaymentRequestTitle, equals('Duplicate Payment Request Already Saved'));
      expect(lAr.duplicatePaymentRequestMessage('PAY-01', 'Test Title').contains('PAY-01'), isTrue);
      expect(lEn.duplicatePaymentRequestMessage('PAY-01', 'Test Title').contains('PAY-01'), isTrue);

      expect(lAr.duplicateBudgetTitle, equals('اعتماد ميزانية محفوظ مسبقاً'));
      expect(lEn.duplicateBudgetTitle, equals('Budget Approval Already Saved'));
      expect(lAr.duplicateBudgetMessage('BGT-01', 'Test Budget').contains('BGT-01'), isTrue);
      expect(lEn.duplicateBudgetMessage('BGT-01', 'Test Budget').contains('BGT-01'), isTrue);

      // Actions
      expect(lAr.viewAndEditPaymentRequest, equals('استعراض وتعديل طلب السداد الحالي'));
      expect(lEn.viewAndEditPaymentRequest, equals('View & Edit Current Payment Request'));
      expect(lAr.viewAndPrintBudget, equals('استعراض وطباعة الميزانية الحالية'));
      expect(lEn.viewAndPrintBudget, equals('View & Print Current Budget'));

      // Sharing & Modals
      expect(lAr.exportAndShareOptionsTitle, equals('خيارات التصدير، الطباعة والمشاركة المباشرة:'));
      expect(lEn.exportAndShareOptionsTitle, equals('Export, Print & Direct Sharing Options:'));
      expect(lAr.sendPaymentWhatsAppTitle, equals('إرسال تفاصيل السداد عبر واتساب'));
      expect(lEn.sendPaymentWhatsAppTitle, equals('Send Payment Details via WhatsApp'));
      expect(lAr.sendPaymentEmailTitle, equals('إرسال طلب السداد عبر البريد الإلكتروني'));
      expect(lEn.sendPaymentEmailTitle, equals('Send Payment Request via Email'));
      expect(lAr.sendBudgetWhatsAppTitle, equals('مشاركة اعتماد الميزانية عبر واتساب'));
      expect(lEn.sendBudgetWhatsAppTitle, equals('Share Budget Approval via WhatsApp'));
      expect(lAr.sendBudgetEmailTitle, equals('إرسال تقرير الميزانية بالبريد الإلكتروني'));
      expect(lEn.sendBudgetEmailTitle, equals('Send Budget Report via Email'));

      // Statuses & Details
      expect(lAr.paymentRequestDetailsTitle('PAY-100'), equals('طلب سداد مالي: PAY-100'));
      expect(lEn.paymentRequestDetailsTitle('PAY-100'), equals('Payment Request: PAY-100'));
      expect(lAr.budgetDetailsTitle('BGT-200'), equals('اعتماد الميزانية: BGT-200'));
      expect(lEn.budgetDetailsTitle('BGT-200'), equals('Budget Approval: BGT-200'));

      // Customs Authority
      expect(lAr.customsAuthority, equals('مصلحة الجمارك'));
      expect(lEn.customsAuthority, equals('Customs Authority'));

      // SWIFT prefixes
      expect(lAr.swiftPaymentPrefix, equals('سداد تحويل سويفت'));
      expect(lEn.swiftPaymentPrefix, equals('SWIFT Wire Transfer Payment'));
      expect(lAr.orderingCustomerPrefix, equals('الآمر بالتحويل'));
      expect(lEn.orderingCustomerPrefix, equals('Ordering Customer / Remitter'));
      expect(lAr.paymentDetailsPrefix, equals('التفاصيل'));
      expect(lEn.paymentDetailsPrefix, equals('Details'));
    });
  });
}

