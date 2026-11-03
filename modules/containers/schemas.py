from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field


class ContainerBase(BaseModel):
    container_number: str = Field(..., description="رقم الحاوية (مثال: MSCU1234567)")
    container_type: str = Field(..., description="نوع الحاوية (مثال: 20GP, 40GP, 40HC, Reefer)")
    seal_number: Optional[str] = Field(None, description="رقم السيل الملاحي")

    import_file_id: int = Field(..., description="معرف الملف الاستيرادي")
    booking_id: Optional[int] = Field(None, description="معرف حجز الشحن")
    shipping_record_id: Optional[int] = Field(None, description="معرف سجل الشحن")
    demurrage_tracking_id: Optional[int] = Field(None, description="معرف جلسة تتبع الغرامات والأرضيات")

    carrier_name: Optional[str] = Field(None, description="اسم الخط الملاحي")
    bill_of_lading_no: Optional[str] = Field(None, description="رقم بوليصة الشحن B/L")

    gate_in_date: Optional[datetime] = Field(None, description="تاريخ دخول ميناء الشحن")
    stuffing_date: Optional[datetime] = Field(None, description="تاريخ التعتيق / الرص والتحميل")
    discharge_date: Optional[date] = Field(None, description="تاريخ التفريغ في ميناء الوصول")
    gate_out_date: Optional[date] = Field(None, description="تاريخ الخروج الفعلي من بوابة الميناء")
    gate_out_timestamp: Optional[datetime] = Field(None, description="التوقيت الدقيق لخروج الحاوية من بوابة الميناء")
    empty_return_date: Optional[date] = Field(None, description="تاريخ إرجاع الحاوية الفارغة للمستودع")
    eir_timestamp: Optional[datetime] = Field(None, description="توقيت توثيق إيصال الإرجاع EIR")

    customs_inspection_seal: Optional[str] = Field(None, description="رقم سيل المعاينة الجمركية")
    truck_plate_number: Optional[str] = Field(None, description="رقم لوحة الشاحنة الناقلة")

    tare_weight_kg: float = Field(0.0, ge=0.0, description="الوزن الفارغ للحاوية بالكيلوجرام")
    net_weight_kg: float = Field(0.0, ge=0.0, description="الوزن الصافي للبضاعة بالكيلوجرام")
    gross_weight_kg: float = Field(0.0, ge=0.0, description="الوزن القائم الإجمالي بالكيلوجرام")
    vgm_weight_kg: float = Field(0.0, ge=0.0, description="الوزن المعتمد VGM بالكيلوجرام")
    vgm_status: str = Field("Pending", description="حالة اعتماد VGM (Pending / Verified)")
    vgm_ref_no: Optional[str] = Field(None, description="رقم شهادة VGM")

    demurrage_days: int = Field(0, ge=0, description="أيام غرامات تأخير الحاوية")
    detention_days: int = Field(0, ge=0, description="أيام حبس الحاوية خارج الميناء")
    storage_days: int = Field(0, ge=0, description="أيام أرضيات الميناء")
    demurrage_cost_fx: float = Field(0.0, ge=0.0, description="تكلفة غرامات التأخير بالعملة الأجنبية")
    detention_cost_fx: float = Field(0.0, ge=0.0, description="تكلفة الحبس بالعملة الأجنبية")
    storage_cost_egp: float = Field(0.0, ge=0.0, description="تكلفة أرضيات الميناء بالجنيه المصري")
    total_cost_egp: float = Field(0.0, ge=0.0, description="إجمالي تكلفة الغرامات والأرضيات بالجنيه")
    individual_demurrage_cost: float = Field(0.0, ge=0.0, description="تكلفة الغرامة الفردية للحاوية")
    currency: str = Field("USD", description="عملة الغرامات")

    status: str = Field("Allocated", description="حالة الحاوية التشغيلية")
    eir_number: Optional[str] = Field(None, description="رقم إيصال استلام الحاوية الفارغة EIR")
    eir_condition_status: Optional[str] = Field("Good", description="حالة الحاوية في إيصال EIR")
    depot_name: Optional[str] = Field(None, description="اسم مستودع إعادة الحاويات")
    condition_at_return: Optional[str] = Field("Good", description="حالة الحاوية عند التسليم")
    notes: Optional[str] = Field(None, description="ملاحظات تشغيلية")


class ContainerCreate(ContainerBase):
    pass


class ContainerUpdate(BaseModel):
    container_number: Optional[str] = None
    container_type: Optional[str] = None
    seal_number: Optional[str] = None
    customs_inspection_seal: Optional[str] = None
    truck_plate_number: Optional[str] = None
    booking_id: Optional[int] = None
    shipping_record_id: Optional[int] = None
    demurrage_tracking_id: Optional[int] = None
    carrier_name: Optional[str] = None
    bill_of_lading_no: Optional[str] = None
    gate_in_date: Optional[datetime] = None
    stuffing_date: Optional[datetime] = None
    discharge_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    gate_out_timestamp: Optional[datetime] = None
    empty_return_date: Optional[date] = None
    eir_timestamp: Optional[datetime] = None
    tare_weight_kg: Optional[float] = None
    net_weight_kg: Optional[float] = None
    gross_weight_kg: Optional[float] = None
    vgm_weight_kg: Optional[float] = None
    vgm_status: Optional[str] = None
    vgm_ref_no: Optional[str] = None
    demurrage_days: Optional[int] = None
    detention_days: Optional[int] = None
    storage_days: Optional[int] = None
    demurrage_cost_fx: Optional[float] = None
    detention_cost_fx: Optional[float] = None
    storage_cost_egp: Optional[float] = None
    total_cost_egp: Optional[float] = None
    individual_demurrage_cost: Optional[float] = None
    currency: Optional[str] = None
    status: Optional[str] = None
    eir_number: Optional[str] = None
    eir_condition_status: Optional[str] = None
    depot_name: Optional[str] = None
    condition_at_return: Optional[str] = None
    notes: Optional[str] = None


class ContainerGateOutRequest(BaseModel):
    gate_out_date: Optional[date] = Field(None, description="تاريخ خروج الحاوية من بوابة الميناء")
    gate_out_timestamp: Optional[datetime] = Field(None, description="التوقيت الدقيق لخروج الحاوية من البوابة")
    truck_plate_number: Optional[str] = Field(None, description="رقم لوحة الشاحنة الناقلة")
    customs_inspection_seal: Optional[str] = Field(None, description="رقم سيل المعاينة الجمركية")
    driver_name: Optional[str] = Field(None, description="اسم السائق")
    notes: Optional[str] = Field(None, description="ملاحظات الخروج")


class ContainerEirReturnRequest(BaseModel):
    eir_number: str = Field(..., min_length=1, description="رقم إيصال استلام الحاوية الفارغة EIR")
    eir_timestamp: Optional[datetime] = Field(None, description="توقيت توثيق إيصال الإرجاع EIR")
    empty_return_date: Optional[date] = Field(None, description="تاريخ تسليم الحاوية الفارغة")
    eir_condition_status: Optional[str] = Field("Good", description="حالة الحاوية في إيصال EIR")
    depot_name: Optional[str] = Field(None, description="اسم مستودع التسليم")
    condition_at_return: Optional[str] = Field("Good", description="حالة الحاوية عند التسليم")
    notes: Optional[str] = Field(None, description="ملاحظات التسليم")


class ContainerEmptyReturnRequest(ContainerEirReturnRequest):
    """Alias for backwards compatibility with earlier return endpoints."""
    pass


class ContainerResponse(ContainerBase):
    model_config = ConfigDict(from_attributes=True)

    container_id: int
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str


class ContainerListResponse(BaseModel):
    total: int
    items: List[ContainerResponse]


class ContainerSyncResponse(BaseModel):
    import_file_id: int
    synced_count: int
    containers: List[ContainerResponse]


class ContainerLedgerItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    container_id: int
    container_number: str
    container_type: str
    seal_number: Optional[str] = None
    customs_inspection_seal: Optional[str] = None
    carrier_name: Optional[str] = None
    bill_of_lading_no: Optional[str] = None
    status: str

    discharge_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    gate_out_timestamp: Optional[datetime] = None
    truck_plate_number: Optional[str] = None

    empty_return_date: Optional[date] = None
    eir_number: Optional[str] = None
    eir_timestamp: Optional[datetime] = None
    eir_condition_status: Optional[str] = None
    depot_name: Optional[str] = None

    demurrage_days: int = 0
    detention_days: int = 0
    storage_days: int = 0
    demurrage_cost_fx: float = 0.0
    detention_cost_fx: float = 0.0
    storage_cost_egp: float = 0.0
    total_cost_egp: float = 0.0
    individual_demurrage_cost: float = 0.0
    currency: str = "USD"

    is_demurrage_stopped: bool = False
    stop_reason: Optional[str] = None
    notes: Optional[str] = None


class ContainerLedgerResponse(BaseModel):
    import_file_id: int
    total_containers: int
    returned_containers: int
    active_containers: int
    total_demurrage_cost_fx: float
    total_cost_egp: float
    currency: str
    totals_by_currency: Optional[dict] = None
    items: List[ContainerLedgerItemResponse]
