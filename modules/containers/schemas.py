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
    empty_return_date: Optional[date] = Field(None, description="تاريخ إرجاع الحاوية الفارغة للمستودع")

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
    currency: str = Field("USD", description="عملة الغرامات")

    status: str = Field("Allocated", description="حالة الحاوية التشغيلية")
    eir_number: Optional[str] = Field(None, description="رقم إيصال استلام الحاوية الفارغة EIR")
    depot_name: Optional[str] = Field(None, description="اسم مستودع إعادة الحاويات")
    condition_at_return: Optional[str] = Field("Good", description="حالة الحاوية عند التسليم")
    notes: Optional[str] = Field(None, description="ملاحظات تشغيلية")


class ContainerCreate(ContainerBase):
    pass


class ContainerUpdate(BaseModel):
    container_number: Optional[str] = None
    container_type: Optional[str] = None
    seal_number: Optional[str] = None
    booking_id: Optional[int] = None
    shipping_record_id: Optional[int] = None
    demurrage_tracking_id: Optional[int] = None
    carrier_name: Optional[str] = None
    bill_of_lading_no: Optional[str] = None
    gate_in_date: Optional[datetime] = None
    stuffing_date: Optional[datetime] = None
    discharge_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    empty_return_date: Optional[date] = None
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
    currency: Optional[str] = None
    status: Optional[str] = None
    eir_number: Optional[str] = None
    depot_name: Optional[str] = None
    condition_at_return: Optional[str] = None
    notes: Optional[str] = None


class ContainerGateOutRequest(BaseModel):
    gate_out_date: date = Field(..., description="تاريخ خروج الحاوية من بوابة الميناء")
    truck_plate_number: Optional[str] = Field(None, description="رقم لوحة الشاحنة الناقلة")
    driver_name: Optional[str] = Field(None, description="اسم السائق")
    notes: Optional[str] = Field(None, description="ملاحظات الخروج")


class ContainerEmptyReturnRequest(BaseModel):
    empty_return_date: date = Field(..., description="تاريخ تسليم الحاوية الفارغة")
    eir_number: str = Field(..., min_length=1, description="رقم إيصال EIR")
    depot_name: Optional[str] = Field(None, description="مستودع التسليم")
    condition_at_return: Optional[str] = Field("Good", description="حالة الحاوية عند الفحص")
    notes: Optional[str] = Field(None, description="ملاحظات التسليم")


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
