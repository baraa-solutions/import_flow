from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from sqlalchemy.orm import Session

from database.database import get_db
from utils.export_import_helper import MasterDataExportImportHelper
from modules.currencies.schemas import (
    CurrencyCreate,
    CurrencyResponse,
    CurrencyUpdate,
    ExchangeRateCreate,
    ExchangeRateResponse,
    CurrencyConversionRequest,
    CurrencyConversionResponse,
    ExchangeGainLossRequest,
    ExchangeGainLossResponse,
)
from modules.currencies.service import CurrencyService

router = APIRouter(prefix="/api/v1/currencies", tags=["Currencies & Exchange Rates (MD-004)"], dependencies=[Depends(get_current_user)])


@router.post("/convert", response_model=CurrencyConversionResponse, summary="Convert amount between currencies using commercial or customs rates")
def convert_currency(
    payload: CurrencyConversionRequest,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.convert_currency(
        amount=payload.amount,
        from_currency_code=payload.from_currency_code,
        to_currency_code=payload.to_currency_code,
        rate_type=payload.rate_type,
        as_of_date=payload.as_of_date,
    )


@router.post("/gain-loss", response_model=ExchangeGainLossResponse, summary="Calculate FX Gain/Loss variance between initial and settlement rates")
def calculate_exchange_gain_loss(
    payload: ExchangeGainLossRequest,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.calculate_gain_loss(
        foreign_amount=payload.foreign_amount,
        currency_code=payload.currency_code,
        initial_rate=payload.initial_rate,
        settlement_rate=payload.settlement_rate,
        initial_date=payload.initial_date,
        settlement_date=payload.settlement_date,
    )


@router.get("", response_model=List[CurrencyResponse])
def get_all_currencies(
    include_inactive: bool = Query(False, description="Include inactive currencies"),
    search: Optional[str] = Query(None, description="Search by currency code or name"),
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.get_all_currencies(include_inactive=include_inactive, search=search)


@router.get("/export-excel", summary="Export all currencies and exchange rates to Excel (XLSX)")
def export_currencies_excel(db: Session = Depends(get_db)):
    service = CurrencyService(db)
    currencies = service.get_all_currencies(include_inactive=True)
    headers = [
        'Currency Code', 'Currency Name', 'Symbol', 'Base Currency',
        'Decimals', 'Commercial Rate (EGP)', 'Customs Rate (EGP)', 'Status'
    ]
    rows = []
    for c in currencies:
        rows.append([
            c.currency_code,
            c.currency_name,
            c.currency_symbol or '',
            'Yes' if c.is_base_currency else 'No',
            c.decimal_places,
            c.latest_commercial_rate if c.latest_commercial_rate is not None else '-',
            c.latest_customs_rate if c.latest_customs_rate is not None else '-',
            'Active' if c.is_active else 'Inactive',
        ])
    content = MasterDataExportImportHelper.export_to_excel("Currencies & Exchange Rates", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Currencies_Exchange_Rates", "xlsx")
    return MasterDataExportImportHelper.as_excel_response(filename, content)


@router.get("/export-pdf", summary="Export all currencies and exchange rates to PDF")
def export_currencies_pdf(db: Session = Depends(get_db)):
    service = CurrencyService(db)
    currencies = service.get_all_currencies(include_inactive=True)
    headers = ['Code', 'Name', 'Symbol', 'Base', 'Commercial Rate', 'Customs Rate', 'Status']
    rows = []
    for c in currencies:
        comm = f"{c.latest_commercial_rate:.4f}" if c.latest_commercial_rate is not None else "-"
        cust = f"{c.latest_customs_rate:.4f}" if c.latest_customs_rate is not None else "-"
        rows.append([
            c.currency_code,
            c.currency_name,
            c.currency_symbol or '',
            'Yes' if c.is_base_currency else 'No',
            comm,
            cust,
            'Active' if c.is_active else 'Inactive',
        ])
    content = MasterDataExportImportHelper.export_to_pdf("Currencies & Exchange Rates (MD-004)", headers, rows)
    filename = MasterDataExportImportHelper.standard_export_filename("Currencies_Exchange_Rates", "pdf")
    return MasterDataExportImportHelper.as_pdf_response(filename, content)


@router.get("/{currency_id}", response_model=CurrencyResponse)
def get_currency_by_id(
    currency_id: int,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.get_currency_by_id(currency_id)


@router.post("", response_model=CurrencyResponse, status_code=status.HTTP_201_CREATED)
def create_currency(
    data: CurrencyCreate,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.create_currency(data)


@router.put("/{currency_id}", response_model=CurrencyResponse)
def update_currency(
    currency_id: int,
    data: CurrencyUpdate,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.update_currency(currency_id, data)


@router.delete("/{currency_id}", response_model=CurrencyResponse)
def soft_delete_currency(
    currency_id: int,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.soft_delete_currency(currency_id)


@router.post("/{currency_id}/restore", response_model=CurrencyResponse)
def restore_currency(
    currency_id: int,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.restore_currency(currency_id)


@router.post(
    "/rates",
    response_model=ExchangeRateResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permission("master_data.edit"))],
)
def add_exchange_rate(
    data: ExchangeRateCreate,
    db: Session = Depends(get_db),
):
    service = CurrencyService(db)
    return service.add_exchange_rate(data)
