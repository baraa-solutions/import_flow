# Import all SQLAlchemy models here
# This file is used by Alembic to discover all tables for migrations and schema verification

from modules.audit_logs.model import AuditLog
from modules.cargo_shipping.model import CargoShippingRecord
from modules.cbm_calculator.model import CBMCalculation, CBMCalculationItem
from modules.container_loader.model import ContainerLoaderSessionModel, ContainerSpecModel
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_consultation.model import (
    BrokerPriceList,
    BrokerPriceListItem,
    ClearanceExpenseType,
    CustomsBrokerQuoteItem,
    CustomsChecklistItem,
    CustomsConsultationSession,
)
from modules.customs_tariff.model import CustomsTariff, FeeCode, PreferentialAgreement
from modules.demurrage_detention.model import DemurragePolicy, DemurrageTracking
from modules.external_service_providers.model import ExternalServiceProvider
from modules.file_closure.model import ImportFileClosureRecord
from modules.financial_approval.model import ImportBudgetApproval, PaymentRequestSession
from modules.financial_settlement.model import LandedCostSettlementRecord, TaxRate
from modules.freight_booking.model import ShipmentBooking
from modules.freight_quotations.model import FreightQuotationItem, FreightRFQRequest
from modules.import_companies.model import ImportCompany
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    CertificateOfOriginReviewSession,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    InspectionCertificateReviewSession,
    POPackingReconciliationSession,
    ShipmentDocumentItem,
)
from modules.import_files.model import ImportFile
from modules.import_requirements.model import ImportRequirementAssessment
from modules.incoterms.model import CostItem, Incoterm, IncotermResponsibility
from modules.lifecycle_board.model import ShipmentStageActivity
from modules.notifications.model import SystemNotification
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PackingListItem, PurchaseOrder
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.smart_document_upload.model import UploadSession
from modules.smart_tasks.model import SmartTask
from modules.suppliers.model import Supplier
from modules.transport_locations.model import TransportLocation
from modules.users.model import User
from modules.warehouse_receiving.model import WarehouseReceivingRecord