import '../../../core/localization/app_localizations.dart';

/// Extension providing 100% pure language separation for Air Freight & Ocean LCL.
/// Adheres strictly to the ERP rule: NO mixing Arabic and English in parentheses.
extension AirLclLocalizationsExtension on AppLocalizations {
  String get airLclDialogTitle =>
      isArabic ? 'تفاصيل الشحن الجوي والشحن البحري المجمع' : 'Air Freight and Ocean LCL Details';

  String get airLclDialogSubtitle => isArabic
      ? 'تسجيل بيانات الرحلات الجوية وبوالص الشحن الجوي ومحطات التجميع ورسوم التفريغ'
      : 'Record flight schedules, air waybills, consolidation terminals and stripping fees';

  String get transportModeLabel => isArabic ? 'نمط النقل والشحن' : 'Transport Mode';

  String get transportModeSeaFcl => isArabic ? 'شحن بحري حاوية كاملة' : 'Ocean Full Container Load';

  String get transportModeSeaLcl => isArabic ? 'شحن بحري مجمع' : 'Ocean Less Container Load';

  String get transportModeAirFreight => isArabic ? 'شحن جوي' : 'Air Freight';

  String get airFreightSectionTitle => isArabic ? 'بيانات ومسار الشحن الجوي' : 'Air Freight Details and Flight Schedule';

  String get flightNumberLabel => isArabic ? 'رقم الرحلة الجوية' : 'Flight Number';

  String get flightNumberHint => isArabic ? 'مثال: إم إس 777' : 'e.g. MS 777';

  String get airlineCodeLabel => isArabic ? 'كود شركة الطيران الناقلة' : 'Airline Carrier Code';

  String get airlineCodeHint => isArabic ? 'مثال: إم إس' : 'e.g. MS';

  String get masterAirWaybillLabel => isArabic ? 'بوليصة الشحن الجوي الرئيسية' : 'Master Air Waybill';

  String get masterAirWaybillHint => isArabic ? 'مثال: 077-12345678' : 'e.g. 077-12345678';

  String get houseAirWaybillLabel => isArabic ? 'بوليصة الشحن الجوي الفرعية' : 'House Air Waybill';

  String get houseAirWaybillHint => isArabic ? 'مثال: 99881' : 'e.g. 99881';

  String get airportTerminalNameLabel => isArabic ? 'قرية البضائع ومحطة المطار' : 'Airport Cargo Terminal';

  String get airportTerminalNameHint =>
      isArabic ? 'مثال: قرية البضائع بمطار القاهرة الدولي' : 'e.g. Cairo International Airport Cargo Terminal';

  String get seaLclSectionTitle => isArabic ? 'بيانات الشحن البحري المجمع ومحطة التجميع' : 'Ocean LCL and Consolidation Terminal Details';

  String get cfsTerminalNameLabel => isArabic ? 'محطة تجميع وتفريغ الحاويات' : 'Container Freight Station Terminal';

  String get cfsTerminalNameHint =>
      isArabic ? 'مثال: محطة المستودعات المصرية بميناء الإسكندرية' : 'e.g. Alexandria CFS Terminal';

  String get strippingFeesEgpLabel => isArabic ? 'رسوم الفك والتفريغ بالجنيه المصري' : 'Stripping and Deconsolidation Fees in Egyptian Pounds';

  String get strippingFeesHint => '0.00';

  String get airVolumetricCalcTitle =>
      isArabic ? 'حاسبة الوزن الحجمي والوزن الخاضع للفوترة' : 'Volumetric and Chargeable Weight Calculator';

  String get lengthCmLabel => isArabic ? 'الطول بالسنتيمتر' : 'Length in Centimeters';

  String get widthCmLabel => isArabic ? 'العرض بالسنتيمتر' : 'Width in Centimeters';

  String get heightCmLabel => isArabic ? 'الارتفاع بالسنتيمتر' : 'Height in Centimeters';

  String get grossWeightKgLabel => isArabic ? 'الوزن الإجمالي الفعلي بالكيلوغرام' : 'Gross Weight in Kilograms';

  String get packageQuantityLabel => isArabic ? 'عدد الطرود' : 'Package Quantity';

  String get calculateWeightBtn => isArabic ? 'حساب الوزن الخاضع للفوترة' : 'Calculate Chargeable Weight';

  String get volumetricWeightResult => isArabic ? 'الوزن الحجمي المعتمد' : 'Volumetric Weight';

  String get chargeableWeightResult => isArabic ? 'الوزن الخاضع للفوترة النهائي' : 'Chargeable Weight';

  String get totalCbmResult => isArabic ? 'الحجم الكلي بالمتر المكعب' : 'Total Volume in Cubic Meters';

  String get higherVolumetricNotice => isArabic
      ? 'تنبيه: الوزن الحجمي أعلى من الوزن الفعلي وسيتم احتساب التكلفة وفق الوزن الحجمي حسب قواعد إياتا الدولية.'
      : 'Notice: Volumetric weight exceeds actual gross weight; billing will follow volumetric weight per IATA standards.';

  String get higherGrossNotice => isArabic
      ? 'تنبيه: الوزن الفعلي أعلى من الوزن الحجمي وسيتم احتساب التكلفة وفق الوزن الفعلي.'
      : 'Notice: Actual gross weight exceeds volumetric weight; billing will follow actual weight.';

  String get saveDetailsBtn => isArabic ? 'حفظ وتحديث البيانات' : 'Save Details';

  String get saveSuccessSnack => isArabic ? 'تم حفظ تفاصيل الشحن بنجاح' : 'Shipment details saved successfully';

  String get saveErrorSnack => isArabic ? 'حدث خطأ أثناء حفظ البيانات' : 'An error occurred while saving details';

  String get copySuccessSnack => isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard';

  String get cfsStrippingNotice => isArabic
      ? 'تخضع الشحنات البحرية المجمعة لرسوم تفريغ وحراسة داخل محطة التجميع قبل الإفراج الجمركي.'
      : 'Consolidated ocean shipments are subject to deconsolidation and storage fees at the CFS terminal prior to customs clearance.';

  String get airLclCardTitle => isArabic ? 'بيانات النمط والشحن المتعدد' : 'Multimodal Transport Specifications';

  String get viewAirLclDetails => isArabic ? 'بيانات الشحن الجوي والمجمع' : 'Air and LCL Details';

  String get applyChargeableWeightToBooking =>
      isArabic ? 'اعتماد الوزن الخاضع للفوترة في الحجز' : 'Apply Chargeable Weight to Booking';

  String get unitKg => isArabic ? 'كجم' : 'kg';

  String get unitCbm => isArabic ? 'متر مكعب' : 'CBM';

  String get unitEgp => isArabic ? 'جنيه مصري' : 'EGP';

  String get cancelBtn => isArabic ? 'إلغاء' : 'Cancel';
}
