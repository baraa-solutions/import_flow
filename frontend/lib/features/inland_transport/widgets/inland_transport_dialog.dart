import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/inland_transport_model.dart';
import '../providers/inland_transport_provider.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/localization/app_localizations.dart';

/// TR-01 Modal Dialog: Inland Transport Coordination
/// حجز وتنسيق سيارات وسائقي النقل الداخلي للمخزن وتتبع زمن الخروج والوصول
class InlandTransportDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const InlandTransportDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, ImportFileModel file) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InlandTransportDialog(file: file),
    );
  }

  @override
  ConsumerState<InlandTransportDialog> createState() => _InlandTransportDialogState();
}

class _InlandTransportDialogState extends ConsumerState<InlandTransportDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showBookingForm = true;
  InlandTransportModel? _existingBooking;

  // Controllers
  late TextEditingController _waybillController;
  late TextEditingController _carrierNameController;
  late TextEditingController _truckPlateController;
  late TextEditingController _driverNameController;
  late TextEditingController _driverPhoneController;
  late TextEditingController _driverNationalIdController;
  late TextEditingController _containerNumbersController;
  late TextEditingController _pickupLocationController;
  late TextEditingController _destinationWarehouseController;
  late TextEditingController _fareEgpController;
  late TextEditingController _trackingNotesController;

  // Gate-Out & Arrival Controllers
  late TextEditingController _gateOutNotesController;
  late TextEditingController _arrivalNotesController;

  String _truckType = 'FLATBED'; // DomainEnumType.truckType code
  DateTime _plannedDepartureDate = DateTime.now();
  final TimeOfDay _plannedDepartureTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _expectedArrivalDate = DateTime.now().add(const Duration(hours: 6));
  final TimeOfDay _expectedArrivalTime = const TimeOfDay(hour: 16, minute: 0);

  final DateTime _actualDepartureDate = DateTime.now();
  final DateTime _actualArrivalDate = DateTime.now();

  List<String> get _truckTypes => [
        ...DomainEnums.codesOf(DomainEnumType.truckType),
        // A legacy free value that is not a known code stays selectable.
        if (!DomainEnums.isCode(DomainEnumType.truckType, _truckType)) _truckType,
      ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadBookingData();
  }

  void _initControllers() {
    final now = DateTime.now();
    final filePort = widget.file.portOfDischarge ?? 'El Dekheila Port (non TMT)';
    final portCode = filePort.toLowerCase().contains('dekheila') ? 'EDK' : 'ALX';
    final randomSuffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');

    _waybillController = TextEditingController(text: 'WB-${now.year}-$portCode-$randomSuffix');
    _carrierNameController = TextEditingController(text: widget.file.inlandCarrierName ?? '');
    _truckPlateController = TextEditingController(text: widget.file.inlandTruckPlateNo ?? '');
    _driverNameController = TextEditingController(text: widget.file.inlandDriverName ?? '');
    _driverPhoneController = TextEditingController(text: widget.file.inlandDriverPhone ?? '');
    _driverNationalIdController = TextEditingController();
    _containerNumbersController = TextEditingController();
    _pickupLocationController = TextEditingController(text: widget.file.portOfDischarge ?? 'El Dekheila Port - Alexandria');
    _destinationWarehouseController = TextEditingController(text: 'Cairo Main Warehouse (6th of October City)');
    _fareEgpController = TextEditingController(
      text: widget.file.inlandTransportCostEgp > 0
          ? widget.file.inlandTransportCostEgp.toStringAsFixed(2)
          : '4500.00',
    );
    _trackingNotesController = TextEditingController();
    _gateOutNotesController = TextEditingController();
    _arrivalNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _waybillController.dispose();
    _carrierNameController.dispose();
    _truckPlateController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverNationalIdController.dispose();
    _containerNumbersController.dispose();
    _pickupLocationController.dispose();
    _destinationWarehouseController.dispose();
    _fareEgpController.dispose();
    _trackingNotesController.dispose();
    _gateOutNotesController.dispose();
    _arrivalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    setState(() => _isLoading = true);
    try {
      final booking = await ref
          .read(inlandTransportProvider.notifier)
          .fetchBookingByFile(widget.file.importFileId);

      if (mounted) {
        setState(() {
          _existingBooking = booking;
          if (booking != null) {
            _showBookingForm = false;
            _carrierNameController.text = booking.carrierName;
            _truckPlateController.text = booking.truckPlateNumber;
            _driverNameController.text = booking.driverName;
            _driverPhoneController.text = booking.driverPhone;
            if (booking.driverNationalId != null) {
              _driverNationalIdController.text = booking.driverNationalId!;
            }
            if (booking.containerNumbers != null) {
              _containerNumbersController.text = booking.containerNumbers!;
            }
            _pickupLocationController.text = booking.pickupPortLocation;
            _destinationWarehouseController.text = booking.destinationWarehouse;
            _fareEgpController.text = booking.transportFareEgp.toStringAsFixed(2);
            if (booking.trackingNotes != null) {
              _trackingNotesController.text = booking.trackingNotes!;
            }
            _truckType = DomainEnums.initialCode(DomainEnumType.truckType, booking.truckType, booking.truckType);
            _waybillController.text = booking.waybillNumber;
          } else {
            _showBookingForm = true;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _autoGenerateWaybill() {
    final now = DateTime.now();
    final filePort = widget.file.portOfDischarge ?? 'EDK';
    final portCode = filePort.toLowerCase().contains('dekheila') ? 'EDK' : 'ALX';
    final randomSuffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    setState(() {
      _waybillController.text = 'WB-${now.year}-$portCode-$randomSuffix';
    });
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final plannedDepartureDateTime = DateTime(
      _plannedDepartureDate.year,
      _plannedDepartureDate.month,
      _plannedDepartureDate.day,
      _plannedDepartureTime.hour,
      _plannedDepartureTime.minute,
    );

    final expectedArrivalDateTime = DateTime(
      _expectedArrivalDate.year,
      _expectedArrivalDate.month,
      _expectedArrivalDate.day,
      _expectedArrivalTime.hour,
      _expectedArrivalTime.minute,
    );

    final fareEgp = double.tryParse(_fareEgpController.text.trim()) ?? 0.0;

    final payload = {
      'import_file_id': widget.file.importFileId,
      'waybill_number': _waybillController.text.trim(),
      'carrier_name': _carrierNameController.text.trim(),
      'truck_plate_number': _truckPlateController.text.trim(),
      'truck_type': _truckType,
      'driver_name': _driverNameController.text.trim(),
      'driver_phone': _driverPhoneController.text.trim(),
      'driver_national_id': _driverNationalIdController.text.trim().isNotEmpty
          ? _driverNationalIdController.text.trim()
          : null,
      'container_numbers': _containerNumbersController.text.trim().isNotEmpty
          ? _containerNumbersController.text.trim()
          : null,
      'pickup_port_location': _pickupLocationController.text.trim(),
      'destination_warehouse': _destinationWarehouseController.text.trim(),
      'planned_departure_at': plannedDepartureDateTime.toIso8601String(),
      'expected_arrival_at': expectedArrivalDateTime.toIso8601String(),
      'transport_fare_egp': fareEgp,
      'tracking_notes': _trackingNotesController.text.trim().isNotEmpty
          ? _trackingNotesController.text.trim()
          : null,
    };

    setState(() => _isSubmitting = true);
    try {
      final created = await ref
          .read(inlandTransportProvider.notifier)
          .createBooking(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حجز وتأكيد النقل الداخلي بنجاح برقم (${created?.transportCode ?? ''}) وترحيل نولون النقل لتكلفة البضاعة',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حجز النقل الداخلي: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _recordGateOut() async {
    if (_existingBooking == null) return;

    final payload = {
      'actual_departure_at': _actualDepartureDate.toIso8601String(),
      'tracking_notes': _gateOutNotesController.text.trim().isNotEmpty
          ? _gateOutNotesController.text.trim()
          : 'Truck left the port gate and is moving to the warehouse',
    };

    setState(() => _isSubmitting = true);
    try {
      final updated = await ref
          .read(inlandTransportProvider.notifier)
          .recordGateOut(_existingBooking!.transportId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تأكيد خروج الشاحنة من بوابة الميناء (Gate-Out) بنجاح برقم (${updated?.transportCode})'),
            backgroundColor: AppTheme.cobalt,
          ),
        );
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل خروج البوابة: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _recordWarehouseArrival() async {
    if (_existingBooking == null) return;

    final payload = {
      'actual_arrival_at': _actualArrivalDate.toIso8601String(),
      'tracking_notes': _arrivalNotesController.text.trim().isNotEmpty
          ? _arrivalNotesController.text.trim()
          : 'Truck arrived at the warehouse unloading dock, ready for receiving and inspection',
    };

    setState(() => _isSubmitting = true);
    try {
      final updated = await ref
          .read(inlandTransportProvider.notifier)
          .recordWarehouseArrival(_existingBooking!.transportId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تأكيد وصول الشاحنة للمخزن واستلامها بنجاح (${updated?.transportCode})'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        await _loadBookingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل وصول المخزن: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Arrived Warehouse':
        return AppTheme.emerald;
      case 'In Transit (Gate-Out)':
        return AppTheme.cobalt;
      case 'Booking Confirmed':
        return AppTheme.flatOrange;
      default:
        return AppTheme.charcoal;
    }
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'Arrived Warehouse':
        return 'تم الوصول للمخزن';
      case 'In Transit (Gate-Out)':
        return 'في الطريق (خرج من الميناء)';
      case 'Booking Confirmed':
        return 'تم تأكيد الحجز';
      default:
        return 'غير محجوز';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 960 ? 920.0 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            _buildDialogHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKpiSummaryCards(),
                          const SizedBox(height: 16),
                          if (_existingBooking != null) ...[
                            _buildExistingBookingCard(),
                            const SizedBox(height: 16),
                          ],
                          if (_showBookingForm) ...[
                            _buildBookingForm(),
                          ],
                        ],
                      ),
                    ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    final status = _existingBooking?.status ?? widget.file.inlandTransportStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تنسيق وحجز سيارات وسائقي النقل الداخلي (TR-01)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'الملف: ${widget.file.primaryNameWithCode}  |  المستورد: ${widget.file.companyName}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _getStatusColor(status)),
                      ),
                      child: Text(
                        _getStatusArabic(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(false),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards() {
    final status = _existingBooking?.status ?? widget.file.inlandTransportStatus;
    final fare = _existingBooking?.transportFareEgp ?? widget.file.inlandTransportCostEgp;
    final driver = _existingBooking?.driverName ?? widget.file.inlandDriverName ?? 'غير محدد';
    final truck = _existingBooking?.truckPlateNumber ?? widget.file.inlandTruckPlateNo ?? 'غير محدد';
    final waybill = _existingBooking?.waybillNumber ?? widget.file.inlandTransportBookingNo ?? 'قيد الإنشاء';

    return Row(
      children: [
        Expanded(
          child: _buildKpiTile(
            title: 'حالة النقل الداخلي',
            value: _getStatusArabic(status),
            icon: Icons.alt_route_rounded,
            color: _getStatusColor(status),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiTile(
            title: 'بوليصة النقل الداخلي',
            value: waybill,
            icon: Icons.receipt_rounded,
            color: AppTheme.cobalt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiTile(
            title: 'الشاحنة والسائق',
            value: '$truck / $driver',
            icon: Icons.person_pin_rounded,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiTile(
            title: 'نولون النقل (EGP)',
            value: '${fare.toStringAsFixed(2)} ج.م',
            icon: Icons.monetization_on_outlined,
            color: AppTheme.emerald,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingBookingCard() {
    final b = _existingBooking!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cobalt.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات حجز النقل الحالية (${b.transportCode})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: Icon(_showBookingForm ? Icons.expand_less : Icons.edit, size: 16),
                label: Text(_showBookingForm ? 'إخفاء نموذج التعديل' : 'تعديل أو إعادة حجز'),
                onPressed: () => setState(() => _showBookingForm = !_showBookingForm),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildInfoRow('شركة النقل:', b.carrierName),
              _buildInfoRow('رقم البوليصة:', b.waybillNumber),
              _buildInfoRow('نوع الشاحنة:', DomainEnums.label(context.l10n, DomainEnumType.truckType, b.truckType)),
              _buildInfoRow('لوحة الشاحنة:', b.truckPlateNumber),
              _buildInfoRow('السائق:', '${b.driverName} (${b.driverPhone})'),
              if (b.containerNumbers != null) _buildInfoRow('الحاويات:', b.containerNumbers!),
              _buildInfoRow('مكان الاستلام:', b.pickupPortLocation),
              _buildInfoRow('المخزن المستلم:', b.destinationWarehouse),
              _buildInfoRow('المغادرة المخططة:', b.plannedDepartureAt.split('T').first),
              _buildInfoRow('الوصول المتوقع:', b.expectedArrivalAt.split('T').first),
              if (b.actualDepartureAt != null)
                _buildInfoRow('المغادرة الفعلية:', b.actualDepartureAt!.split('T').first),
              if (b.actualArrivalAt != null)
                _buildInfoRow('الوصول الفعلي:', b.actualArrivalAt!.split('T').first),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons based on status
          if (b.status == 'Booking Confirmed') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cobalt.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.departure_board, color: AppTheme.cobalt),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تأكيد خروج الشاحنة من بوابة الميناء (Port Gate-Out)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'تسجيل توقيت المغادرة الفعلي وبدء تتبع الرحلة وتحويل الحالة إلى "في الطريق"',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('inlandGateOutBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('تأكيد خروج البوابة (Gate-Out)'),
                    onPressed: _isSubmitting ? null : _recordGateOut,
                  ),
                ],
              ),
            ),
          ] else if (b.status == 'In Transit (Gate-Out)') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warehouse_rounded, color: AppTheme.emerald),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تأكيد وصول واستلام الشاحنة بالمخزن (Warehouse Arrival)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'تسجيل وصول الشاحنة لرصيف المخزن وتحديث نسبة إنجاز الملف إلى 100% وإتاحة استلام الأصناف',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const Key('inlandWarehouseArrivalBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.done_all, size: 16),
                    label: const Text('تأكيد وصول المخزن'),
                    onPressed: _isSubmitting ? null : _recordWarehouseArrival,
                  ),
                ],
              ),
            ),
          ] else if (b.status == 'Arrived Warehouse') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.emerald),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم وصول واستلام الشاحنة بنجاح بالمخزن، وتم ربط مهمة الاستلام والفحص التلقائي (TR-03).',
                      style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBookingForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, color: AppTheme.charcoal, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'نموذج حجز وتنسيق النقل الداخلي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('inlandAutoWaybillBtn'),
                  icon: const Icon(Icons.auto_mode, size: 14),
                  label: const Text('توليد بوليصة تلقائياً', style: TextStyle(fontSize: 12)),
                  onPressed: _autoGenerateWaybill,
                ),
              ],
            ),
            const Divider(height: 20),

            // Row 1: Waybill & Carrier
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('inlandWaybillNoField'),
                    controller: _waybillController,
                    decoration: const InputDecoration(
                      labelText: 'رقم بوليصة النقل الداخلي (Waybill No) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'يرجى إدخال رقم البوليصة' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    key: const Key('inlandCarrierNameField'),
                    controller: _carrierNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم شركة النقل / الناقل *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'يرجى إدخال اسم شركة النقل' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: Truck Plate & Truck Type
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('inlandTruckPlateField'),
                    controller: _truckPlateController,
                    decoration: const InputDecoration(
                      labelText: 'رقم لوحة الشاحنة / السيارة *',
                      hintText: 'مثال: ط د ر 7541 / د س 128',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().length < 3) ? 'رقم اللوحة لا يقل عن 3 أحرف/أرقام' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SearchableDropdownField<String>(
                    key: const Key('inlandTruckTypeDropdown'),
                    labelText: 'نوع الشاحنة والمقطورة *',
                    hintText: 'اختر نوع الشاحنة',
                    value: _truckType,
                    items: _truckTypes
                        .map((t) => SearchableDropdownItem<String>(
                            value: t, label: DomainEnums.label(context.l10n, DomainEnumType.truckType, t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _truckType = val);
                    },
                    validator: (val) => (val == null || val.isEmpty) ? 'يرجى اختيار نوع الشاحنة' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 3: Driver Name & Driver Phone & National ID
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const Key('inlandDriverNameField'),
                    controller: _driverNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم السائق الثلاثي *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().length < 3) ? 'يرجى إدخال اسم السائق صحيحاً' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('inlandDriverPhoneField'),
                    controller: _driverPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف السائق *',
                      hintText: '01012345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().length < 8) ? 'رقم الهاتف غير صالح' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _driverNationalIdController,
                    decoration: const InputDecoration(
                      labelText: 'الرقم القومي للسائق',
                      hintText: '14 رقم (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 4: Pickup Location & Destination Warehouse
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pickupLocationController,
                    decoration: const InputDecoration(
                      labelText: 'مكان وميناء الاستلام *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'يرجى تحديد مكان الاستلام' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _destinationWarehouseController,
                    decoration: const InputDecoration(
                      labelText: 'المخزن المستلم (الوجهة) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warehouse),
                    ),
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'يرجى تحديد المخزن المستلم' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 5: Containers & Fare EGP
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _containerNumbersController,
                    decoration: const InputDecoration(
                      labelText: 'أرقام الحاويات المنقولة',
                      hintText: 'مثال: MSKU9876543, MEDU1234567',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.view_in_ar),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('inlandFareEgpField'),
                    controller: _fareEgpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'نولون النقل (EGP) *',
                      hintText: '4500.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'ج.م',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'يرجى إدخال تكلفة النقل';
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) return 'المبلغ يجب أن يكون أكبر من 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 6: Departure & Arrival Date Pickers
            Row(
              children: [
                Expanded(
                  child: Material(type: MaterialType.transparency, child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ المغادرة المخططة', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${_plannedDepartureDate.year}-${_plannedDepartureDate.month.toString().padLeft(2, '0')}-${_plannedDepartureDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _plannedDepartureDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _plannedDepartureDate = picked);
                    },
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Material(type: MaterialType.transparency, child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الوصول المتوقع للمخزن (ETA)', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${_expectedArrivalDate.year}-${_expectedArrivalDate.month.toString().padLeft(2, '0')}-${_expectedArrivalDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.event_available, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expectedArrivalDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _expectedArrivalDate = picked);
                    },
                  )),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 7: Notes
            TextFormField(
              controller: _trackingNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات وتوجيهات السائق والشحن',
                hintText: 'تعليمات الحذر في التعتيق، تفاصيل السائق المساعد، مسار السير...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                key: const Key('inlandSubmitBookingBtn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 18),
                label: const Text('حفظ وتأكيد حجز النقل الداخلي'),
                onPressed: _isSubmitting ? null : _submitBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_alt, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تحديث فوري لنسبة إنجاز الملف ومزامنة شاشة تتبع الشحنات والمخزن',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إغلاق النافذة'),
          ),
        ],
      ),
    );
  }
}
