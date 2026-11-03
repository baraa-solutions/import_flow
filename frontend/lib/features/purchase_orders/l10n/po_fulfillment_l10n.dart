import '../../../core/localization/app_localizations.dart';

/// Pure localization extension for PO Fulfillment & Partial Shipments (EPIC-PO-PART).
/// Strictly 100% pure language separation with zero mixed English/Arabic parentheses.
extension POFulfillmentL10n on AppLocalizations {
  String get poFulfillmentProgressTitle =>
      isArabic ? 'ميزان إنجاز التوريد' : 'Fulfillment Balance';

  String get poFulfillmentSubtitle =>
      isArabic ? 'موقف شحن واستلام كميات أمر الشراء' : 'Order Shipment & Receipt Progress';

  String get poContractedQty =>
      isArabic ? 'الكمية المتعاقد عليها' : 'Contracted Quantity';

  String get poShippedQty =>
      isArabic ? 'الكمية المشحونة' : 'Shipped Quantity';

  String get poReceivedQty =>
      isArabic ? 'الكمية المستلمة' : 'Received Quantity';

  String get poRemainingQty =>
      isArabic ? 'الرصيد المتبقي' : 'Remaining Balance';

  String get poFulfillmentPercent =>
      isArabic ? 'نسبة الإنجاز' : 'Fulfillment Rate';

  String get poStatusOpen =>
      isArabic ? 'مفتوح' : 'Open';

  String get poStatusPartiallyShipped =>
      isArabic ? 'شحن جزئي' : 'Partially Shipped';

  String get poStatusFullyShipped =>
      isArabic ? 'مكتمل التوريد' : 'Fully Shipped';

  String get poStatusOverShipped =>
      isArabic ? 'تجاوز الكمية' : 'Over Shipped';

  String get poCreatePartialShipment =>
      isArabic ? 'تخصيص دفعة شحن جزئية' : 'Allocate Partial Shipment';

  String get poCreatePartialShipmentBtn =>
      isArabic ? 'شحن جزئي' : 'Partial Shipment';

  String get poShipmentBatchNo =>
      isArabic ? 'رقم دفعة الشحن أو البوليصة' : 'Shipment Batch or Bill of Lading';

  String get poShipmentBatchNoHint =>
      isArabic ? 'مثال: الدفعة الأولى أو رقم البوليصة' : 'e.g. Batch 1 or BL Number';

  String get poTargetLineItem =>
      isArabic ? 'بند أمر الشراء المستهدف' : 'Target Purchase Order Item';

  String get poGeneralAllocationOption =>
      isArabic ? 'تخصيص عام لكامل أمر الشراء' : 'General Allocation for Entire Order';

  String get poAssociatedImportFile =>
      isArabic ? 'ملف الاستيراد المرتبط' : 'Associated Import File';

  String get poAssociatedImportFileOptional =>
      isArabic ? 'اختياري: ربط بملف استيرادي محدد' : 'Optional: Link to Specific Import File';

  String get poAllocatedQuantity =>
      isArabic ? 'الكمية المخصصة للشحن' : 'Allocated Shipment Quantity';

  String get poAllocatedFobAmount =>
      isArabic ? 'القيمة التعاقدية للشحنة' : 'Contract Value of Shipment';

  String get poShippingDate =>
      isArabic ? 'تاريخ الشحن' : 'Shipping Date';

  String get poAllocationBatchStatus =>
      isArabic ? 'حالة دفعة الشحن' : 'Shipment Batch Status';

  String get poStatusInTransit =>
      isArabic ? 'قيد الشحن الدولي' : 'In Transit';

  String get poStatusArrived =>
      isArabic ? 'وصلت الميناء' : 'Arrived at Port';

  String get poStatusCustomsCleared =>
      isArabic ? 'تم الإفراج الجمركي' : 'Customs Cleared';

  String get poStatusWarehouseReceived =>
      isArabic ? 'مستلمة بالمستودع' : 'Received at Warehouse';

  String get poAllocationNotes =>
      isArabic ? 'ملاحظات وتفاصيل الدفعة' : 'Batch Details and Notes';

  String get poSaveAllocationBtn =>
      isArabic ? 'حفظ وتخصيص الدفعة' : 'Save and Allocate Batch';

  String get poAllocationSuccess =>
      isArabic ? 'تم تسجيل تخصيص دفعة الشحن الجزئي بنجاح' : 'Partial shipment allocated successfully';

  String get poAllocationFailed =>
      isArabic ? 'فشل تسجيل تخصيص الشحنة' : 'Failed to allocate shipment';

  String get poQuantityRequired =>
      isArabic ? 'يرجى إدخال كمية صالحة أكبر من الصفر' : 'Please enter a valid quantity greater than zero';

  String get poBatchNumberRequired =>
      isArabic ? 'يرجى إدخال رقم الدفعة أو البوليصة' : 'Please enter batch or BL number';

  String get poRemainingExceededWarning =>
      isArabic ? 'تنبيه: الكمية المخصصة تتجاوز الرصيد المتبقي' : 'Warning: Allocated quantity exceeds remaining balance';

  String get poAllocationsListTitle =>
      isArabic ? 'سجل دفعات الشحن السابقة' : 'Previous Shipment Batches Log';

  String get poNoAllocationsYet =>
      isArabic ? 'لم يتم تسجيل أي شحنات جزئية لهذا الأمر بعد' : 'No partial shipments allocated yet for this order';

  String get poUnitsLabel =>
      isArabic ? 'وحدة' : 'units';
}
